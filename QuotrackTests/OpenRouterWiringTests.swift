import Foundation
import Testing

/// Proves the OpenRouter adapter is reachable through every production seam:
/// the live Provider registry, the live data source the monitor polls, and the
/// onboarding connection tester.
struct OpenRouterWiringTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let account = Account(id: UUID(), provider: .openRouter, label: "管理账户")

    @Test
    func theLiveRegistryRoutesOpenRouterAccountsToTheRealAdapter() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: OpenRouterFixtures.success)
        )
        let registry = ProviderRegistry.live(
            credentialStore: credentials(),
            transport: transport,
            now: { now }
        )

        let snapshot = try await registry.fetchBalance(for: account)

        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "74.75")!, currency: .usd)
        )
        #expect(transport.requests.first?.url == OpenRouterAdapter.endpoint)
        #expect(
            transport.requests.first?.headers["Authorization"]
                == "Bearer sk-or-management"
        )
    }

    @Test @MainActor
    func theLiveDataSourceLoadsAccountsAndPollsThemThroughTheRealAdapter() async {
        let transport = StubHTTPTransport(
            response: .json(body: OpenRouterFixtures.success)
        )
        let store = InMemorySnapshotStore(accounts: [account])
        let dataSource = BalanceDataSource.make(
            mode: .live,
            store: store,
            credentialStore: credentials(),
            transport: transport
        )

        #expect(dataSource.accounts == [account])

        let monitor = LiveBalanceMonitor(
            dataSource: dataSource,
            pollingInterval: 300,
            now: { now }
        )
        await monitor.refresh()

        #expect(
            monitor.rows.first?.snapshot?.balance
                == Balance(amount: Decimal(string: "74.75")!, currency: .usd)
        )
        #expect(transport.requests.first?.url == OpenRouterAdapter.endpoint)
    }

    @Test
    func theLiveConnectionTesterSendsTheEnteredManagementKeyToOpenRouter() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: OpenRouterFixtures.success)
        )
        let tester = ProviderRegistryConnectionTester.live(
            credentialStore: InMemoryCredentialStore(),
            transport: transport,
            now: { now }
        )

        let snapshot = try await tester.testConnection(
            provider: .openRouter,
            region: nil,
            credential: "sk-or-entered"
        )

        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "74.75")!, currency: .usd)
        )
        #expect(snapshot.isAvailable)
        #expect(
            transport.requests.first?.headers["Authorization"]
                == "Bearer sk-or-entered"
        )
    }

    private func credentials() -> InMemoryCredentialStore {
        InMemoryCredentialStore(credentials: [account.id: "sk-or-management"])
    }
}
