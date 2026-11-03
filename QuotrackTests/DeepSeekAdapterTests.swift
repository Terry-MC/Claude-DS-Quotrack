import Foundation
import Testing

struct DeepSeekAdapterTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")

    @Test
    func fetchesTheBalanceWithTheAccountsBearerCredential() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: DeepSeekFixtures.success)
        )
        let credentials = InMemoryCredentialStore(
            credentials: [account.id: "sk-test"]
        )
        let adapter = DeepSeekAdapter(
            transport: transport,
            credentialStore: credentials,
            now: { now }
        )

        let snapshot = try await adapter.fetchBalance(for: account)

        #expect(snapshot.accountID == account.id)
        #expect(snapshot.balance == Balance(amount: Decimal(string: "110.00")!, currency: .cny))
        #expect(snapshot.isAvailable)
        #expect(snapshot.fetchedAt == now)
        #expect(snapshot.breakdown == [
            BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "10.00")!),
            BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "100.00")!),
        ])

        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.method == "GET")
        #expect(request.url.absoluteString == "https://api.deepseek.com/user/balance")
        #expect(request.headers["Authorization"] == "Bearer sk-test")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.body == nil)
    }

    @Test(arguments: [
        (401, BalanceProviderError.Category.authentication),
        (403, BalanceProviderError.Category.permission),
    ])
    func authorizationFailuresMapToTypedErrors(
        status: Int,
        category: BalanceProviderError.Category
    ) async throws {
        let transport = StubHTTPTransport(
            response: .json(status: status, body: #"{"error":"denied"}"#)
        )
        let adapter = makeAdapter(transport: transport)

        await #expect(throws: BalanceProviderError(category)) {
            try await adapter.fetchBalance(for: account)
        }
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
    func transportFailuresMapToNetwork() async throws {
        let transport = StubHTTPTransport(error: URLError(.notConnectedToInternet))
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .network)
    }

    @Test
    func malformedJSONMapsToMalformedResponse() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: #"{"is_available": true, "balance_infos": ["#)
        )
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .malformedResponse)
    }

    @Test(arguments: [
        #"{}"#,
        #"{"is_available": true}"#,
        #"{"is_available": true, "balance_infos": []}"#,
        #"{"is_available": true, "balance_infos": [{"currency": "CNY", "granted_balance": "10.00"}]}"#,
        #"{"is_available": true, "balance_infos": [{"currency": "CNY", "total_balance": "not-a-number"}]}"#,
    ])
    func missingRequiredFieldsMapToMalformedResponse(body: String) async throws {
        let transport = StubHTTPTransport(response: .json(body: body))
        let adapter = makeAdapter(transport: transport)

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .malformedResponse)
    }

    @Test @MainActor
    func anUnavailableBalanceIsShownAsUnavailableInsteadOfAnError() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: DeepSeekFixtures.unavailable)
        )
        let adapter = makeAdapter(transport: transport)
        let monitor = LiveBalanceMonitor(
            provider: adapter,
            accounts: [account],
            pollingInterval: 300,
            now: { now }
        )

        await monitor.refresh()

        let row = try #require(monitor.rows.first)
        #expect(row.snapshot?.isAvailable == false)
        #expect(
            row.snapshot?.balance
                == Balance(amount: Decimal(string: "0.00")!, currency: .usd)
        )
        #expect(row.status == .unavailable)
        #expect(row.error == nil)
        #expect(
            BalanceRowPresentation.viewState(for: row, now: now).statusText == "不可用"
        )
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
    func anAccountWithoutAStoredCredentialFailsAsAuthenticationWithoutACall() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: DeepSeekFixtures.success)
        )
        let adapter = DeepSeekAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )

        let error = await providerError(from: adapter, account: account)
        #expect(error.category == .authentication)
        #expect(transport.requests.isEmpty)
    }

    @Test
    func breakdownIncludesOnlyTheFieldsTheProviderReports() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: """
            {
              "is_available": true,
              "balance_infos": [
                {
                  "currency": "USD",
                  "total_balance": "7.50",
                  "topped_up_balance": "7.50"
                }
              ]
            }
            """)
        )
        let adapter = makeAdapter(transport: transport)

        let snapshot = try await adapter.fetchBalance(for: account)

        #expect(snapshot.balance == Balance(amount: Decimal(string: "7.50")!, currency: .usd))
        #expect(snapshot.breakdown == [
            BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "7.50")!),
        ])
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
    func aZeroForeignBalanceDoesNotHideTheNonZeroCNYBalance() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: """
            {
              "is_available": true,
              "balance_infos": [
                {
                  "currency": "USD",
                  "total_balance": "0.00",
                  "granted_balance": "0.00",
                  "topped_up_balance": "0.00"
                },
                {
                  "currency": "CNY",
                  "total_balance": "21.00",
                  "granted_balance": "0.00",
                  "topped_up_balance": "21.00"
                }
              ]
            }
            """)
        )
        let adapter = makeAdapter(transport: transport)

        let snapshot = try await adapter.fetchBalance(for: account)

        #expect(snapshot.balance == Balance(amount: Decimal(string: "21.00")!, currency: .cny))
        #expect(snapshot.breakdown == [
            BalanceBreakdownItem(kind: .granted, amount: 0),
            BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "21.00")!),
        ])
    }

    @Test
    func multipleBalanceInfosPreferTheNonZeroCNYEntryWithoutAggregating() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: """
            {
              "is_available": true,
              "balance_infos": [
                {
                  "currency": "CNY",
                  "total_balance": "110.00",
                  "granted_balance": "10.00",
                  "topped_up_balance": "100.00"
                },
                {
                  "currency": "USD",
                  "total_balance": "15.00",
                  "granted_balance": "0.00",
                  "topped_up_balance": "15.00"
                }
              ]
            }
            """)
        )
        let adapter = makeAdapter(transport: transport)

        let snapshot = try await adapter.fetchBalance(for: account)

        #expect(snapshot.balance == Balance(amount: Decimal(string: "110.00")!, currency: .cny))
    }

    private func makeAdapter(transport: StubHTTPTransport) -> DeepSeekAdapter {
        DeepSeekAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [account.id: "sk-test"]
            ),
            now: { now }
        )
    }
}
