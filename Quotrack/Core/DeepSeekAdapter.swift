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
struct DeepSeekAdapter: CredentialBalanceAdapter {
    static let endpoint = URL(string: "https://api.deepseek.com/user/balance")!

    private static let amountLocale = Locale(identifier: "en_US_POSIX")

    private let http: AuthenticatedHTTPClient
    private let now: @Sendable () -> Date

    init(
        transport: any HTTPTransport,
        credentialStore: any CredentialStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.http = AuthenticatedHTTPClient(
            transport: transport,
            credentialStore: credentialStore,
            now: now
        )
        self.now = now
    }

    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        let response = try await http.get(Self.endpoint, accountID: account.id)
        return try snapshot(from: response, accountID: account.id)
    }

    /// The onboarding path: the credential has not been saved to an Account
    /// yet, so the tester supplies it directly.
    func fetchBalance(region: Region?, credential: String) async throws -> BalanceSnapshot {
        let response = try await http.get(Self.endpoint, credential: credential)
        return try snapshot(from: response, accountID: UUID())
    }

    private func snapshot(
        from response: HTTPResponse,
        accountID: Account.ID
    ) throws -> BalanceSnapshot {
        do {
            let decoded = try JSONDecoder().decode(BalanceResponse.self, from: response.body)
            guard let info = Self.selectBalanceInfo(from: decoded.balanceInfos) else {
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

    /// DeepSeek can return one entry per currency. Prefer a non-zero CNY
    /// balance, then any non-zero entry, then a zero CNY entry, then the first
    /// entry. This stops a zero USD entry from hiding a real CNY balance.
    private static func selectBalanceInfo(from infos: [BalanceInfo]) -> BalanceInfo? {
        guard !infos.isEmpty else {
            return nil
        }
        if let cny = infos.first(where: { isCNY($0) && isNonZero($0.totalBalance) }) {
            return cny
        }
        if let nonZero = infos.first(where: { isNonZero($0.totalBalance) }) {
            return nonZero
        }
        if let cny = infos.first(where: isCNY) {
            return cny
        }
        return infos.first
    }

    private static func isCNY(_ info: BalanceInfo) -> Bool {
        info.currency.uppercased() == "CNY"
    }

    private static func isNonZero(_ string: String) -> Bool {
        guard let value = decimal(string) else {
            return false
        }
        return value != 0
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
