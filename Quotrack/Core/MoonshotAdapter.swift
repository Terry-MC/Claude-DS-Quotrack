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
struct MoonshotAdapter: CredentialBalanceAdapter {
    static let domesticEndpoint = URL(
        string: "https://api.moonshot.cn/v1/users/me/balance"
    )!
    static let internationalEndpoint = URL(
        string: "https://api.moonshot.ai/v1/users/me/balance"
    )!

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
        let response = try await http.get(
            Self.endpoint(for: account.region),
            accountID: account.id
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
        let response = try await http.get(
            Self.endpoint(for: region),
            credential: credential
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

    private func snapshot(
        from response: HTTPResponse,
        accountID: Account.ID,
        region: Region?
    ) throws -> BalanceSnapshot {
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
