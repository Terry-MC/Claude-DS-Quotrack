import Foundation
import Testing

struct OpenRouterAdapterTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let account = Account(id: UUID(), provider: .openRouter, label: "管理账户")

    @Test
    func fetchesTheBalanceAsCreditsMinusUsageWithTheManagementKey() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: OpenRouterFixtures.success)
        )
        let credentials = InMemoryCredentialStore(
            credentials: [account.id: "sk-or-management"]
        )
        let adapter = OpenRouterAdapter(
            transport: transport,
            credentialStore: credentials,
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(for: account)

        #expect(snapshot.accountID == account.id)
        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "74.75")!, currency: .usd)
        )
        #expect(snapshot.isAvailable)
        #expect(snapshot.fetchedAt == now)
        #expect(snapshot.breakdown == [
            BalanceBreakdownItem(
                kind: .totalCredits,
                amount: Decimal(string: "100.5")!
            ),
            BalanceBreakdownItem(kind: .usage, amount: Decimal(string: "25.75")!),
        ])

        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.method == "GET")
        #expect(request.url.absoluteString == "https://openrouter.ai/api/v1/credits")
        #expect(request.headers["Authorization"] == "Bearer sk-or-management")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.body == nil)
    }

    @Test
    func aNormalInferenceKeyForbiddenResponseShowsTheManagementKeyMessage() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 403,
                body: OpenRouterFixtures.inferenceKeyForbidden
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = try await providerError(from: adapter)

        #expect(error.category == .permission)
        #expect(error.userMessage(for: .openRouter) == UIStrings.openRouterManagementKeyError)
    }

    @Test
    func anInvalidOrMissingManagementKeyMapsToAuthentication() async throws {
        let transport = StubHTTPTransport(
            response: .json(status: 401, body: #"{"error":{"code":401}}"#)
        )
        let adapter = makeAdapter(transport: transport)

        let error = try await providerError(from: adapter)

        #expect(error.category == .authentication)
    }

    @Test
    func rateLimitWithoutRetryAfterFallsBackToNormalBackoff() async throws {
        let transport = StubHTTPTransport(
            response: .json(status: 429, body: #"{"error":{"code":429}}"#)
        )
        let adapter = makeAdapter(transport: transport)

        let error = try await providerError(from: adapter)

        #expect(error.category == .rateLimit)
        #expect(error.retryAfter == nil)
    }

    @Test
    func rateLimitCarriesTheProvidersRetryAfterDelay() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 429,
                body: #"{"error":{"code":429}}"#,
                headers: ["Retry-After": "120"]
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = try await providerError(from: adapter)

        #expect(error.category == .rateLimit)
        #expect(error.retryAfter == 120)
    }

    @Test
    func retryAfterAcceptsAnHTTPDate() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 429,
                body: "{}",
                headers: ["Retry-After": "Fri, 15 Jan 2027 08:01:00 GMT"]
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = try await providerError(from: adapter)

        #expect(error.category == .rateLimit)
        #expect(error.retryAfter == 60)
    }

    @Test(arguments: [
        #"{"data":{"total_credits":100.5"#,
        #"{}"#,
        #"{"data":{}}"#,
        #"{"data":{"total_credits":100.5}}"#,
        #"{"data":{"total_usage":25.75}}"#,
        #"{"data":{"total_credits":"100.5","total_usage":25.75}}"#,
        #"{"data":{"total_credits":100.5,"total_usage":"25.75"}}"#,
    ])
    func malformedJSONAndMissingFieldsMapToMalformedResponse(body: String) async throws {
        let transport = StubHTTPTransport(response: .json(body: body))
        let adapter = makeAdapter(transport: transport)

        let error = try await providerError(from: adapter)

        #expect(error.category == .malformedResponse)
    }

    @Test
    func transportFailuresMapToNetwork() async throws {
        let transport = StubHTTPTransport(error: URLError(.notConnectedToInternet))
        let adapter = makeAdapter(transport: transport)

        let error = try await providerError(from: adapter)

        #expect(error.category == .network)
    }

    @Test
    func unexpectedStatusMapsToUnknown() async throws {
        let transport = StubHTTPTransport(
            response: .json(status: 500, body: #"{"error":{"code":500}}"#)
        )
        let adapter = makeAdapter(transport: transport)

        let error = try await providerError(from: adapter)

        #expect(error.category == .unknown)
    }

    @Test
    func anAccountWithoutAStoredCredentialFailsAsAuthenticationWithoutACall() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: OpenRouterFixtures.success)
        )
        let adapter = OpenRouterAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )

        let error = try await providerError(from: adapter)

        #expect(error.category == .authentication)
        #expect(transport.requests.isEmpty)
    }

    private func providerError(from adapter: OpenRouterAdapter) async throws -> BalanceProviderError {
        do {
            _ = try await adapter.fetchBalance(for: account)
            Issue.record("Expected the fetch to fail, but it succeeded.")
            return .unknown
        } catch let error as BalanceProviderError {
            return error
        } catch {
            Issue.record("Expected a typed Provider error, got \(error).")
            return .unknown
        }
    }

    private func makeAdapter(transport: StubHTTPTransport) -> OpenRouterAdapter {
        OpenRouterAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [account.id: "sk-or-management"]
            ),
            now: { now }
        )
    }
}
