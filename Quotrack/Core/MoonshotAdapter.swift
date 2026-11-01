import Foundation

/// The Moonshot (Kimi) balance adapter. Moonshot credentials are locked to a
/// Region, so the adapter selects the domestic or international endpoint from
/// the Account before sending the Bearer credential.
///
/// Endpoint and response shape verified 2026-11-01 against
/// https://platform.kimi.com/docs/api/balance and
/// https://platform.kimi.ai/docs/api/balance:
/// `GET /v1/users/me/balance`, Bearer auth, and
/// `{ code, data: { available_balance, voucher_balance, cash_balance },
/// scode, status }` with amounts encoded as JSON numbers. The response carries
/// no currency field: the domestic deployment reports CNY and the
/// international deployment reports USD.
struct MoonshotAdapter: BalanceProvider, CredentialBalanceAdapter {
    static let domesticEndpoint = URL(
        string: "https://api.moonshot.cn/v1/users/me/balance"
    )!
    static let internationalEndpoint = URL(
        string: "https://api.moonshot.ai/v1/users/me/balance"
    )!

    private let transport: any HTTPTransport
    private let credentialStore: any CredentialStore
    private let now: @Sendable () -> Date

    init(
        transport: any HTTPTransport,
        credentialStore: any CredentialStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.credentialStore = credentialStore
        self.now = now
    }

    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        let credential = try credential(for: account.id)
        let response = try await send(
            request(credential: credential, region: account.region)
        )
        return try snapshot(
            from: response,
            accountID: account.id,
            region: account.region
        )
    }

    /// The onboarding path: the credential has not been saved to an Account
    /// yet, so the tester supplies it directly.
    func fetchBalance(region: Region?, credential: String) async throws -> BalanceSnapshot {
        let response = try await send(
            request(credential: credential, region: region)
        )
        return try snapshot(
            from: response,
            accountID: UUID(),
            region: region
        )
    }

    /// Selects the deployment the credential belongs to. A missing Region
    /// defaults to domestic, matching the app's Account default.
    static func endpoint(for region: Region?) -> URL {
        switch region ?? .domestic {
        case .domestic: domesticEndpoint
        case .international: internationalEndpoint
        }
    }

    /// Moonshot reports no currency field, so the Region determines it: the
    /// domestic deployment bills in CNY and the international one in USD.
    static func currency(for region: Region?) -> Currency {
        switch region ?? .domestic {
        case .domestic: .cny
        case .international: .usd
        }
    }

    private func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        do {
            return try await transport.send(request)
        } catch let error as BalanceProviderError {
            throw error
        } catch {
            // URLError and other transport failures become the shared network
            // category so the monitor never sees a raw Foundation error.
            throw BalanceProviderError.classify(error)
        }
    }

    private func credential(for accountID: Account.ID) throws -> String {
        do {
            guard
                let stored = try credentialStore.credential(for: accountID),
                !stored.isEmpty
            else {
                throw BalanceProviderError.authentication
            }
            return stored
        } catch let error as BalanceProviderError {
            throw error
        } catch {
            throw BalanceProviderError.classify(error)
        }
    }

    private func request(credential: String, region: Region?) -> HTTPRequest {
        HTTPRequest(
            url: Self.endpoint(for: region),
            headers: [
                "Authorization": "Bearer \(credential)",
                "Accept": "application/json",
            ]
        )
    }

    private func snapshot(
        from response: HTTPResponse,
        accountID: Account.ID,
        region: Region?
    ) throws -> BalanceSnapshot {
        guard (200..<300).contains(response.statusCode) else {
            throw error(for: response)
        }
        do {
            let decoded = try JSONDecoder().decode(BalanceResponse.self, from: response.body)
            return BalanceSnapshot(
                accountID: accountID,
                balance: Balance(
                    amount: decoded.data.availableBalance,
                    currency: Self.currency(for: region)
                ),
                fetchedAt: now(),
                isAvailable: true,
                breakdown: [
                    BalanceBreakdownItem(kind: .voucher, amount: decoded.data.voucherBalance),
                    BalanceBreakdownItem(kind: .cash, amount: decoded.data.cashBalance),
                ]
            )
        } catch {
            // Invalid JSON, a missing required field, or a wrong field type
            // all mean the documented contract was not met.
            throw BalanceProviderError.malformedResponse
        }
    }

    /// Moonshot credentials are Region-locked, so a 401 commonly means the
    /// credential was sent to the wrong deployment. It stays an authentication
    /// error; the Region hint lives in the user-facing message.
    private func error(for response: HTTPResponse) -> BalanceProviderError {
        switch response.statusCode {
        case 401: .authentication
        case 403: .permission
        case 429: .rateLimit(retryAfter: Self.retryAfter(from: response, now: now()))
        default: .unknown
        }
    }

    /// `Retry-After` is optional: when it is absent or unparseable the monitor
    /// falls back to its normal backoff.
    private static func retryAfter(
        from response: HTTPResponse,
        now: Date
    ) -> TimeInterval? {
        guard
            let raw = response.header("Retry-After")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }
        if let seconds = TimeInterval(raw) {
            return seconds >= 0 ? seconds : nil
        }
        if let date = httpDate(raw) {
            return max(0, date.timeIntervalSince(now))
        }
        return nil
    }

    /// HTTP-date form of `Retry-After`, for Providers that send it instead of
    /// a number of seconds. RFC 1123 is the preferred HTTP-date format.
    private static func httpDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: string)
    }
}

/// The Moonshot response. The three balances are nested under `data` and are
/// JSON numbers by contract.
private struct BalanceResponse: Decodable {
    let data: BalanceData
}

private struct BalanceData: Decodable {
    let availableBalance: Decimal
    let voucherBalance: Decimal
    let cashBalance: Decimal

    enum CodingKeys: String, CodingKey {
        case availableBalance = "available_balance"
        case voucherBalance = "voucher_balance"
        case cashBalance = "cash_balance"
    }
}
