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
struct OpenRouterAdapter: BalanceProvider, CredentialBalanceAdapter {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/credits")!

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
                    BalanceBreakdownItem(kind: .usage, amount: decoded.data.totalUsage),
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

    /// OpenRouter documents 401 as an invalid or missing credential, 403 as
    /// "insufficient permissions" (an inference key reaches the endpoint but
    /// only a management key may read credits), and 429 as a rate limit. Every
    /// other status is unclassified in v1. `Retry-After` is optional: when
    /// absent or unparseable the monitor falls back to its normal backoff.
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
