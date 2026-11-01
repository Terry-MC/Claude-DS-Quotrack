import Foundation
import Testing

/// Proves the Moonshot adapter is reachable through every production seam:
/// the live Provider registry, the live data source the monitor polls, and the
/// onboarding connection tester.
struct MoonshotWiringTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let domesticAccount = Account(
        id: UUID(),
        provider: .moonshot,
        region: .domestic,
        label: "Kimi 国内"
    )
    private let internationalAccount = Account(
        id: UUID(),
        provider: .moonshot,
        region: .international,
        label: "Kimi 国际"
    )

    @Test
    func theLiveRegistryRoutesMoonshotAccountsToTheRealAdapter() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: MoonshotFixtures.success)
        )
        let registry = ProviderRegistry.live(
            credentialStore: InMemoryCredentialStore(
                credentials: [domesticAccount.id: "sk-moonshot"]
            ),
            transport: transport,
            now: { now }
        )

        let snapshot = try await registry.fetchBalance(for: domesticAccount)

        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "49.58894")!, currency: .cny)
        )
        let request = try #require(transport.requests.first)
        #expect(request.url == MoonshotAdapter.domesticEndpoint)
        #expect(request.headers["Authorization"] == "Bearer sk-moonshot")
    }

    @Test @MainActor
    func theLiveDataSourceLoadsMoonshotAccountsAndPollsThemThroughTheRealAdapter() async {
        let transport = StubHTTPTransport(
            response: .json(body: MoonshotFixtures.success)
        )
        let store = InMemorySnapshotStore(accounts: [internationalAccount])
        let dataSource = BalanceDataSource.make(
            mode: .live,
            store: store,
            credentialStore: InMemoryCredentialStore(
                credentials: [internationalAccount.id: "sk-international"]
            ),
            transport: transport
        )

        #expect(dataSource.accounts == [internationalAccount])

        let monitor = LiveBalanceMonitor(
            dataSource: dataSource,
            pollingInterval: 300,
            now: { now }
        )
        await monitor.refresh()

        #expect(
            monitor.rows.first?.snapshot?.balance
                == Balance(amount: Decimal(string: "49.58894")!, currency: .usd)
        )
        #expect(transport.requests.first?.url == MoonshotAdapter.internationalEndpoint)
    }

    @Test
    func theLiveConnectionTesterSendsTheEnteredCredentialToMoonshot() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: MoonshotFixtures.success)
        )
        let tester = ProviderRegistryConnectionTester.live(
            credentialStore: InMemoryCredentialStore(),
            transport: transport,
            now: { now }
        )

        let snapshot = try await tester.testConnection(
            provider: .moonshot,
            region: .international,
            credential: "sk-entered"
        )

        #expect(snapshot.balance.currency == .usd)
        let request = try #require(transport.requests.first)
        #expect(request.url == MoonshotAdapter.internationalEndpoint)
        #expect(request.headers["Authorization"] == "Bearer sk-entered")
    }
}
