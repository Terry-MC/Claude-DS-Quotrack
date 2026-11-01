import Foundation

/// The SiliconFlow balance adapter. It calls the documented individual
/// user-info endpoint with the Account's Bearer credential and maps the
/// response into the shared domain model.
///
/// Contract recorded 2026-11-01 from the official OpenAPI document
/// (https://raw.githubusercontent.com/siliconflow/siliconcloud/main/openapi.yaml)
/// and the live endpoints: `GET /v1/user/info`, Bearer auth, and
/// `{ data: { balance, chargeBalance, totalBalance } }` with amounts encoded as
/// strings. `balance` is the granted portion, `chargeBalance` the charged
/// portion, and `totalBalance` their total.
///
/// **Live verification pending:** no real SiliconFlow credential has been used
/// yet, so this adapter is unverified against a successful live response. See
/// `docs/manual/siliconflow-live-verification.md`.
struct SiliconFlowAdapter: BalanceProvider, CredentialBalanceAdapter {
    static let domesticEndpoint = URL(string: "https://api.siliconflow.cn/v1/user/info")!
    static let internationalEndpoint = URL(string: "https://api.siliconflow.com/v1/user/info")!

    private static let amountLocale = Locale(identifier: "en_US_POSIX")

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
        let response = try await send(credential: credential, region: account.region)
        return try snapshot(
            from: response,
            accountID: account.id,
            region: account.region
        )
    }

    /// The onboarding path: the credential has not been saved to an Account
    /// yet, so the tester supplies it directly.
    func fetchBalance(region: Region?, credential: String) async throws -> BalanceSnapshot {
        let response = try await send(credential: credential, region: region)
        return try snapshot(from: response, accountID: UUID(), region: region)
    }

    private func send(
        credential: String,
        region: Region?
    ) async throws -> HTTPResponse {
        do {
            return try await transport.send(
                request(credential: credential, region: region)
            )
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
            let decoded = try JSONDecoder().decode(UserInfoResponse.self, from: response.body)
            guard
                let total = Self.decimal(decoded.data.totalBalance),
                let granted = Self.decimal(decoded.data.balance),
                let charged = Self.decimal(decoded.data.chargeBalance)
            else {
                throw BalanceProviderError.malformedResponse
            }
            return BalanceSnapshot(
                accountID: accountID,
                balance: Balance(amount: total, currency: Self.currency(for: region)),
                fetchedAt: now(),
                isAvailable: true,
                breakdown: [
                    BalanceBreakdownItem(kind: .granted, amount: granted),
                    BalanceBreakdownItem(kind: .toppedUp, amount: charged),
                ]
            )
        } catch let error as BalanceProviderError {
            throw error
        } catch {
            // Invalid JSON, a missing required field, or a wrong field type
            // all mean the documented contract was not met.
            throw BalanceProviderError.malformedResponse
        }
    }

    private static func decimal(_ string: String) -> Decimal? {
        Decimal(string: string, locale: amountLocale)
    }

    /// SiliconFlow documents 401 as an authentication failure, 403 as a
    /// permission failure, and 429 as a rate limit. Every other status is
    /// unclassified until the adapter is verified live.
    private func error(for response: HTTPResponse) -> BalanceProviderError {
        switch response.statusCode {
        case 401: .authentication
        case 403: .permission
        case 429: .rateLimit(retryAfter: Self.retryAfter(from: response, now: now()))
        default: .unknown
        }
    }

    private static func retryAfter(from response: HTTPResponse, now: Date) -> TimeInterval? {
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

    /// A credential is valid only in its Region. The domestic endpoint is the
    /// default because existing Accounts and onboarding predate Regions.
    private static func endpoint(for region: Region?) -> URL {
        switch region {
        case .international: internationalEndpoint
        case .domestic, nil: domesticEndpoint
        }
    }

    /// SiliconFlow bills the domestic platform in CNY and the international
    /// platform in USD. Amounts are never converted.
    private static func currency(for region: Region?) -> Currency {
        region == .international ? .usd : .cny
    }
}

/// The SiliconFlow user-info response. Only the balance fields are used; the
/// documented amounts are strings, not numbers.
private struct UserInfoResponse: Decodable {
    let data: UserInfoData
}

private struct UserInfoData: Decodable {
    let balance: String
    let chargeBalance: String
    let totalBalance: String
}
