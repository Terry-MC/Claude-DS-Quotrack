import Foundation

/// The OpenRouter balance adapter. It calls the documented credits endpoint
/// with the Account's management key and reports the remaining Balance as
/// `total_credits - total_usage` in USD.
///
/// Endpoint and response shape verified 2026-11-01 against
/// https://openrouter.ai/docs/api-reference/get-credits:
/// `GET https://openrouter.ai/api/v1/credits`, management-key Bearer auth, and
/// `{ data: { total_credits, total_usage } }` with amounts encoded as JSON
/// numbers.
///
/// Live verification is pending a real management key; see
/// `docs/manual/openrouter-live-verification.md`.
struct OpenRouterAdapter: CredentialBalanceAdapter {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/credits")!

    private let http: AuthenticatedHTTPClient
    private let now: @Sendable () -> Date

    init(
        transport: any HTTPTransport,
        credentialStore: any CredentialStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        // OpenRouter requires a management key, so 401 and 403 both mean the
        // credential lacks the permission this endpoint needs.
        self.http = AuthenticatedHTTPClient(
            transport: transport,
            credentialStore: credentialStore,
            unauthorized: .permission,
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
            let decoded = try JSONDecoder().decode(CreditsResponse.self, from: response.body)
            return BalanceSnapshot(
                accountID: accountID,
                balance: Balance(
                    amount: decoded.data.totalCredits - decoded.data.totalUsage,
                    currency: .usd
                ),
                fetchedAt: now(),
                isAvailable: true,
                breakdown: [
                    BalanceBreakdownItem(
                        kind: .totalCredits,
                        amount: decoded.data.totalCredits
                    ),
                    BalanceBreakdownItem(kind: .spend, amount: decoded.data.totalUsage),
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

}

/// The OpenRouter credits response. Amounts are JSON numbers by contract.
private struct CreditsResponse: Decodable {
    let data: CreditsData
}

private struct CreditsData: Decodable {
    let totalCredits: Decimal
    let totalUsage: Decimal

    enum CodingKeys: String, CodingKey {
        case totalCredits = "total_credits"
        case totalUsage = "total_usage"
    }
}
