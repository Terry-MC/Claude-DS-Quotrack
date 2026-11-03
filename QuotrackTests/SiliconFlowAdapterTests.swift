import Foundation
import Testing

struct SiliconFlowAdapterTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let account = Account(
        id: UUID(),
        provider: .siliconFlow,
        region: .domestic,
        label: "硅基流动"
    )

    @Test
    func fetchesTheDomesticBalanceWithTheAccountsBearerCredential() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: SiliconFlowFixtures.domesticSuccess)
        )
        let credentials = InMemoryCredentialStore(
            credentials: [account.id: "sk-test"]
        )
        let adapter = SiliconFlowAdapter(
            transport: transport,
            credentialStore: credentials,
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(for: account)

        #expect(snapshot.accountID == account.id)
        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "88.88")!, currency: .cny)
        )
        #expect(snapshot.isAvailable)
        #expect(snapshot.fetchedAt == now)
        #expect(snapshot.breakdown == [
            BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "0.88")!),
            BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "88.00")!),
        ])

        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.method == "GET")
        #expect(request.url.absoluteString == "https://api.siliconflow.cn/v1/user/info")
        #expect(request.headers["Authorization"] == "Bearer sk-test")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.body == nil)
    }

    @Test
    func fetchesTheInternationalBalanceFromTheInternationalEndpointInUSD() async throws {
        let internationalAccount = Account(
            id: UUID(),
            provider: .siliconFlow,
            region: .international,
            label: "SiliconFlow Global"
        )
        let transport = StubHTTPTransport(
            response: .json(body: SiliconFlowFixtures.internationalSuccess)
        )
        let credentials = InMemoryCredentialStore(
            credentials: [internationalAccount.id: "sk-global"]
        )
        let adapter = SiliconFlowAdapter(
            transport: transport,
            credentialStore: credentials,
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(for: internationalAccount)

        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "25.00")!, currency: .usd)
        )
        #expect(snapshot.breakdown == [
            BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "1.25")!),
            BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "23.75")!),
        ])

        let request = try #require(transport.requests.first)
        #expect(
            request.url.absoluteString
                == "https://api.siliconflow.com/v1/user/info"
        )
        #expect(request.headers["Authorization"] == "Bearer sk-global")
    }

    @Test
    func unauthorizedMapsToAuthentication() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 401,
                body: #"{"code":30014,"message":"Token is invalid."}"#
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .authentication)
    }

    @Test
    func unauthorizedSuggestsCheckingTheRegionBecauseKeysAreRegionLocked() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 401,
                body: #"{"code":30014,"message":"Token is invalid."}"#
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)

        #expect(error.category == .authentication)
        #expect(error.userMessage(for: .siliconFlow).contains("区域"))
    }

    @Test
    func forbiddenMapsToPermission() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 403,
                body: #"{"code":30003,"message":"Forbidden."}"#
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .permission)
    }

    @Test
    func rateLimitWithoutRetryAfterFallsBackToNormalBackoff() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 429,
                body: #"{"code":30001,"message":"Rate limit reached."}"#
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .rateLimit)
        #expect(error.retryAfter == nil)
    }

    @Test
    func rateLimitCarriesTheProvidersRetryAfterDelay() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 429,
                body: #"{"code":30001,"message":"Rate limit reached."}"#,
                headers: ["Retry-After": "120"]
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
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

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .rateLimit)
        #expect(error.retryAfter == 60)
    }

    @Test
    func malformedJSONMapsToMalformedResponse() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: #"{"data": {"balance": "0.88""#)
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .malformedResponse)
    }

    @Test(arguments: [
        #"{}"#,
        #"{"data": {}}"#,
        #"{"data": {"chargeBalance": "88.00", "totalBalance": "88.88"}}"#,
        #"{"data": {"balance": "0.88", "totalBalance": "88.88"}}"#,
        #"{"data": {"balance": "0.88", "chargeBalance": "88.00"}}"#,
        #"{"data": {"balance": "0.88", "chargeBalance": "88.00", "totalBalance": "not-a-number"}}"#,
        #"{"data": {"balance": "0.88", "chargeBalance": "88.00", "totalBalance": 88.88}}"#,
    ])
    func missingOrInvalidFieldsMapToMalformedResponse(body: String) async throws {
        let transport = StubHTTPTransport(response: .json(body: body))
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .malformedResponse)
    }

    @Test
    func transportFailuresMapToNetwork() async throws {
        let transport = StubHTTPTransport(error: URLError(.notConnectedToInternet))
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .network)
    }

    @Test
    func unexpectedStatusMapsToUnknown() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 500,
                body: #"{"code":50000,"message":"Server error."}"#
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .unknown)
    }

    @Test
    func anAccountWithoutAStoredCredentialFailsAsAuthenticationWithoutACall() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: SiliconFlowFixtures.domesticSuccess)
        )
        let adapter = SiliconFlowAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .authentication)
        #expect(transport.requests.isEmpty)
    }

    @Test
    func anAccountWithoutARegionDefaultsToTheDomesticEndpointAndCNY() async throws {
        let accountWithoutRegion = Account(
            id: UUID(),
            provider: .siliconFlow,
            label: "硅基流动"
        )
        let transport = StubHTTPTransport(
            response: .json(body: SiliconFlowFixtures.domesticSuccess)
        )
        let adapter = SiliconFlowAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [accountWithoutRegion.id: "sk-test"]
            ),
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(for: accountWithoutRegion)

        #expect(snapshot.balance.currency == .cny)
        #expect(transport.requests.first?.url == SiliconFlowAdapter.domesticEndpoint)
    }

    @Test
    func theConnectionTestUsesTheEnteredCredentialAndRegion() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: SiliconFlowFixtures.internationalSuccess)
        )
        let adapter = SiliconFlowAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(
            region: .international,
            credential: "sk-entered"
        )

        #expect(snapshot.balance.currency == .usd)
        #expect(snapshot.breakdown?.first?.amount == Decimal(string: "1.25")!)
        #expect(transport.requests.first?.url == SiliconFlowAdapter.internationalEndpoint)
        #expect(transport.requests.first?.headers["Authorization"] == "Bearer sk-entered")
    }

    private func makeAdapter(transport: StubHTTPTransport) -> SiliconFlowAdapter {
        SiliconFlowAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [account.id: "sk-test"]
            ),
            now: { now }
        )
    }
}
