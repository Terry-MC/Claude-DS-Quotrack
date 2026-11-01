import Foundation

/// The DeepSeek balance adapter. It calls the documented individual balance
/// endpoint with the Account's Bearer credential and maps the response into the
/// shared domain model.
///
/// Endpoint and response shape verified 2026-11-01 against
/// https://api-docs.deepseek.com/api/get-user-balance:
/// `GET https://api.deepseek.com/user/balance`, Bearer auth, and
/// `{ is_available, balance_infos: [{ currency, total_balance,
/// granted_balance, topped_up_balance }] }` with amounts encoded as strings.
struct DeepSeekAdapter: BalanceProvider, CredentialBalanceAdapter {
    static let endpoint = URL(string: "https://api.deepseek.com/user/balance")!

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
        let response = try await send(credential: credential)
        return try snapshot(from: response, accountID: account.id)
    }

    /// The onboarding path: the credential has not been saved to an Account
    /// yet, so the tester supplies it directly.
    func fetchBalance(region: Region?, credential: String) async throws -> BalanceSnapshot {
        let response = try await send(credential: credential)
        return try snapshot(from: response, accountID: UUID())
    }

    private func send(credential: String) async throws -> HTTPResponse {
        do {
            return try await transport.send(request(credential: credential))
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

    private func request(credential: String) -> HTTPRequest {
        HTTPRequest(
            url: Self.endpoint,
            headers: [
                "Authorization": "Bearer \(credential)",
                "Accept": "application/json",
            ]
        )
    }

    private func snapshot(
        from response: HTTPResponse,
        accountID: Account.ID
    ) throws -> BalanceSnapshot {
        guard (200..<300).contains(response.statusCode) else {
            throw error(for: response)
        }
        do {
            let decoded = try JSONDecoder().decode(BalanceResponse.self, from: response.body)
            guard let info = decoded.balanceInfos.first else {
                throw BalanceProviderError.malformedResponse
            }
            guard let total = Self.decimal(info.totalBalance) else {
                throw BalanceProviderError.malformedResponse
            }
            return BalanceSnapshot(
                accountID: accountID,
                balance: Balance(
                    amount: total,
                    currency: Self.currency(for: info.currency)
                ),
                fetchedAt: now(),
                isAvailable: decoded.isAvailable,
                breakdown: try breakdown(for: info)
            )
        } catch let error as BalanceProviderError {
            throw error
        } catch {
            // Invalid JSON, a missing required field, or a wrong field type
            // all mean the documented contract was not met.
            throw BalanceProviderError.malformedResponse
        }
    }

    private func breakdown(for info: BalanceInfo) throws -> [BalanceBreakdownItem]? {
        var items: [BalanceBreakdownItem] = []
        if let granted = info.grantedBalance {
            guard let amount = Self.decimal(granted) else {
                throw BalanceProviderError.malformedResponse
            }
            items.append(BalanceBreakdownItem(kind: .granted, amount: amount))
        }
        if let toppedUp = info.toppedUpBalance {
            guard let amount = Self.decimal(toppedUp) else {
                throw BalanceProviderError.malformedResponse
            }
            items.append(BalanceBreakdownItem(kind: .toppedUp, amount: amount))
        }
        return items.isEmpty ? nil : items
    }

    /// DeepSeek documents 401 as an authentication failure, 403 as a
    /// permission failure, and 429 as a rate limit. Every other status is
    /// unclassified in v1. `Retry-After` is optional: when absent or
    /// unparseable the monitor falls back to its normal backoff.
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

    private static func decimal(_ string: String) -> Decimal? {
        Decimal(string: string, locale: amountLocale)
    }

    private static func currency(for code: String) -> Currency {
        switch code.uppercased() {
        case "CNY": .cny
        case "USD": .usd
        default: Currency(code: code.uppercased(), symbol: code.uppercased())
        }
    }
}

/// The DeepSeek response. Amounts are strings by contract, not numbers.
private struct BalanceResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

private struct BalanceInfo: Decodable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String?
    let toppedUpBalance: String?

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}
