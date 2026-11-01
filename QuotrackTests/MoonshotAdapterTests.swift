import Foundation
import Testing

struct MoonshotAdapterTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let account = Account(
        id: UUID(),
        provider: .moonshot,
        region: .domestic,
        label: "Kimi 国内"
    )

    @Test
    func domesticRegionFetchesTheBalanceFromTheDomesticEndpoint() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: MoonshotFixtures.success)
        )
        let credentials = InMemoryCredentialStore(
            credentials: [account.id: "sk-moonshot"]
        )
        let adapter = MoonshotAdapter(
            transport: transport,
            credentialStore: credentials,
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(for: account)

        #expect(snapshot.accountID == account.id)
        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "49.58894")!, currency: .cny)
        )
        #expect(snapshot.isAvailable)
        #expect(snapshot.fetchedAt == now)
        #expect(snapshot.breakdown == [
            BalanceBreakdownItem(kind: .voucher, amount: Decimal(string: "46.58893")!),
            BalanceBreakdownItem(kind: .cash, amount: Decimal(string: "3.00001")!),
        ])

        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.method == "GET")
        #expect(
            request.url.absoluteString
                == "https://api.moonshot.cn/v1/users/me/balance"
        )
        #expect(request.headers["Authorization"] == "Bearer sk-moonshot")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.body == nil)
    }

    @Test
    func internationalRegionSelectsTheInternationalEndpointAndUSD() async throws {
        let internationalAccount = Account(
            id: UUID(),
            provider: .moonshot,
            region: .international,
            label: "Kimi 国际"
        )
        let transport = StubHTTPTransport(
            response: .json(body: MoonshotFixtures.success)
        )
        let adapter = MoonshotAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [internationalAccount.id: "sk-international"]
            ),
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(for: internationalAccount)

        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "49.58894")!, currency: .usd)
        )
        let request = try #require(transport.requests.first)
        #expect(
            request.url.absoluteString
                == "https://api.moonshot.ai/v1/users/me/balance"
        )
        #expect(request.headers["Authorization"] == "Bearer sk-international")
    }

    @Test
    func aWrongRegionCredentialFailsAsAuthenticationAndMentionsTheRegion() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                status: 401,
                body: #"{"error":{"message":"Invalid Authentication"}}"#
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)

        #expect(error.category == .authentication)
        #expect(error.userMessage(for: .moonshot).contains("区域"))
    }

    @Test
    func forbiddenMapsToPermission() async throws {
        let transport = StubHTTPTransport(
            response: .json(status: 403, body: #"{"error":"forbidden"}"#)
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)

        #expect(error.category == .permission)
    }

    @Test
    func rateLimitWithoutRetryAfterFallsBackToNormalBackoff() async throws {
        let transport = StubHTTPTransport(
            response: .json(status: 429, body: #"{"error":"rate limited"}"#)
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
                body: #"{"error":"rate limited"}"#,
                headers: ["Retry-After": "120"]
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)

        #expect(error.category == .rateLimit)
        #expect(error.retryAfter == 120)
    }

    @Test
    func malformedJSONMapsToMalformedResponse() async throws {
        let transport = StubHTTPTransport(
            response: .json(
                body: #"{"code":0,"data":{"available_balance":49.5"#
            )
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)

        #expect(error.category == .malformedResponse)
    }

    @Test(arguments: [
        #"{}"#,
        #"{"code":0}"#,
        #"{"code":0,"data":{}}"#,
        #"{"code":0,"data":{"voucher_balance":46.58893,"cash_balance":3.00001}}"#,
        #"{"code":0,"data":{"available_balance":49.58894,"cash_balance":3.00001}}"#,
        #"{"code":0,"data":{"available_balance":49.58894,"voucher_balance":46.58893}}"#,
        #"{"code":0,"data":{"available_balance":"49.58894","voucher_balance":46.58893,"cash_balance":3.00001}}"#,
        #"{"code":0,"data":{"available_balance":49.58894,"voucher_balance":46.58893,"cash_balance":null}}"#,
    ])
    func missingOrInvalidFieldsMapToMalformedResponse(body: String) async throws {
        let transport = StubHTTPTransport(response: .json(body: body))
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)

        #expect(error.category == .malformedResponse)
    }

    @Test
    func unexpectedStatusMapsToUnknown() async throws {
        let transport = StubHTTPTransport(
            response: .json(status: 500, body: #"{"error":"server error"}"#)
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)

        #expect(error.category == .unknown)
    }

    @Test
    func transportFailuresMapToNetwork() async throws {
        let transport = StubHTTPTransport(error: URLError(.notConnectedToInternet))
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)

        #expect(error.category == .network)
    }

    @Test
    func anAccountWithoutAStoredCredentialFailsAsAuthenticationWithoutACall() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: MoonshotFixtures.success)
        )
        let adapter = MoonshotAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )

        let error = await providerError(from: adapter, account: account)

        #expect(error.category == .authentication)
        #expect(transport.requests.isEmpty)
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

    @Test(arguments: [
        (
            Region?.none,
            "https://api.moonshot.cn/v1/users/me/balance",
            Currency.cny
        ),
        (
            Region?.some(.domestic),
            "https://api.moonshot.cn/v1/users/me/balance",
            Currency.cny
        ),
        (
            Region?.some(.international),
            "https://api.moonshot.ai/v1/users/me/balance",
            Currency.usd
        ),
    ])
    func theConnectionTestSendsTheEnteredCredentialToTheSelectedRegion(
        region: Region?,
        expectedURL: String,
        expectedCurrency: Currency
    ) async throws {
        let transport = StubHTTPTransport(
            response: .json(body: MoonshotFixtures.success)
        )
        let adapter = MoonshotAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(
            region: region,
            credential: "sk-entered"
        )

        #expect(snapshot.balance.currency == expectedCurrency)
        let request = try #require(transport.requests.first)
        #expect(request.url.absoluteString == expectedURL)
        #expect(request.headers["Authorization"] == "Bearer sk-entered")
    }

    @Test
    func anAccountWithoutARegionDefaultsToTheDomesticDeployment() async throws {
        let accountWithoutRegion = Account(
            id: UUID(),
            provider: .moonshot,
            label: "Kimi 默认"
        )
        let transport = StubHTTPTransport(
            response: .json(body: MoonshotFixtures.success)
        )
        let adapter = MoonshotAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [accountWithoutRegion.id: "sk-moonshot"]
            ),
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(for: accountWithoutRegion)

        #expect(snapshot.balance.currency == .cny)
        #expect(transport.requests.first?.url == MoonshotAdapter.domesticEndpoint)
    }

    @Test
    func aNegativeCashBalanceIsParsedWithoutClamping() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: """
            {
              "code": 0,
              "data": {
                "available_balance": 46.58893,
                "voucher_balance": 46.58893,
                "cash_balance": -3.41
              },
              "scode": "0x0",
              "status": true
            }
            """)
        )
        let adapter = makeAdapter(transport: transport)

        let snapshot = try await adapter.fetchBalance(for: account)

        #expect(
            snapshot.breakdown == [
                BalanceBreakdownItem(kind: .voucher, amount: Decimal(string: "46.58893")!),
                BalanceBreakdownItem(kind: .cash, amount: Decimal(string: "-3.41")!),
            ]
        )
    }

    private func makeAdapter(transport: StubHTTPTransport) -> MoonshotAdapter {
        MoonshotAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [account.id: "sk-moonshot"]
            ),
            now: { now }
        )
    }
}
