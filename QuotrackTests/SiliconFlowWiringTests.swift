import Foundation
import Testing

/// Proves the SiliconFlow adapter is reachable through every production seam:
/// the live Provider registry, the live data source the monitor polls, and the
/// onboarding connection tester.
struct SiliconFlowWiringTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func theLiveRegistryRoutesSiliconFlowAccountsToTheRealAdapter() async throws {
        let account = Account(
            id: UUID(),
            provider: .siliconFlow,
            region: .international,
            label: "SiliconFlow Global"
        )
        let transport = StubHTTPTransport(
            response: .json(body: SiliconFlowFixtures.internationalSuccess)
        )
        let registry = ProviderRegistry.live(
            credentialStore: InMemoryCredentialStore(
                credentials: [account.id: "sk-test"]
            ),
            transport: transport,
            now: { now }
        )

        let snapshot = try await registry.fetchBalance(for: account)

        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "25.00")!, currency: .usd)
        )
        #expect(
            transport.requests.first?.url
                == SiliconFlowAdapter.internationalEndpoint
        )
        #expect(transport.requests.first?.headers["Authorization"] == "Bearer sk-test")
    }

    @Test @MainActor
    func theLiveDataSourceLoadsAccountsAndPollsThemThroughTheRealAdapter() async {
        let account = Account(
            id: UUID(),
            provider: .siliconFlow,
            region: .domestic,
            label: "硅基流动"
        )
        let transport = StubHTTPTransport(
            response: .json(body: SiliconFlowFixtures.domesticSuccess)
        )
        let store = InMemorySnapshotStore(accounts: [account])
        let dataSource = BalanceDataSource.make(
            mode: .live,
            store: store,
            credentialStore: InMemoryCredentialStore(
                credentials: [account.id: "sk-test"]
            ),
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
                == Balance(amount: Decimal(string: "88.88")!, currency: .cny)
        )
        #expect(transport.requests.first?.url == SiliconFlowAdapter.domesticEndpoint)
    }

    @Test
    func theLiveConnectionTesterSendsTheEnteredCredentialAndRegionToSiliconFlow() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: SiliconFlowFixtures.internationalSuccess)
        )
        let tester = ProviderRegistryConnectionTester.live(
            credentialStore: InMemoryCredentialStore(),
            transport: transport,
            now: { now }
        )

        let snapshot = try await tester.testConnection(
            provider: .siliconFlow,
            region: .international,
            credential: "sk-entered"
        )

        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "25.00")!, currency: .usd)
        )
        #expect(snapshot.isAvailable)
        #expect(
            transport.requests.first?.url
                == SiliconFlowAdapter.internationalEndpoint
        )
        #expect(transport.requests.first?.headers["Authorization"] == "Bearer sk-entered")
    }
}
