import Foundation
import Testing

/// Proves the DeepSeek adapter is reachable through every production seam:
/// the live Provider registry, the live data source the monitor polls, and the
/// onboarding connection tester.
struct DeepSeekWiringTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")

    @Test
    func theLiveRegistryRoutesDeepSeekAccountsToTheRealAdapter() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: DeepSeekFixtures.success)
        )
        let registry = ProviderRegistry.live(
            credentialStore: credentials(),
            transport: transport,
            now: { now }
        )

        let snapshot = try await registry.fetchBalance(for: account)

        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "110.00")!, currency: .cny)
        )
        #expect(transport.requests.first?.headers["Authorization"] == "Bearer sk-test")
    }

    @Test
    func providersWithoutAnAdapterStillFailHonestly() async {
        let registry = ProviderRegistry.live(
            credentialStore: credentials(),
            transport: StubHTTPTransport(response: .json(body: DeepSeekFixtures.success)),
            now: { now }
        )
        let moonshotAccount = Account(id: UUID(), provider: .moonshot, label: "Kimi")

        await #expect(throws: BalanceProviderError.unknown) {
            try await registry.fetchBalance(for: moonshotAccount)
        }
    }

    @Test @MainActor
    func theLiveDataSourceLoadsAccountsAndPollsThemThroughTheRealAdapter() async {
        let transport = StubHTTPTransport(
            response: .json(body: DeepSeekFixtures.success)
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
                == Balance(amount: Decimal(string: "110.00")!, currency: .cny)
        )
        #expect(transport.requests.first?.url == DeepSeekAdapter.endpoint)
    }

    @Test
    func theLiveConnectionTesterSendsTheEnteredCredentialToDeepSeek() async throws {
        let transport = StubHTTPTransport(
            response: .json(body: DeepSeekFixtures.success)
        )
        let tester = ProviderRegistryConnectionTester.live(
            credentialStore: InMemoryCredentialStore(),
            transport: transport,
            now: { now }
        )

        let snapshot = try await tester.testConnection(
            provider: .deepSeek,
            region: nil,
            credential: "sk-entered"
        )

        #expect(
            snapshot.balance
                == Balance(amount: Decimal(string: "110.00")!, currency: .cny)
        )
        #expect(snapshot.isAvailable)
        #expect(transport.requests.first?.headers["Authorization"] == "Bearer sk-entered")
    }

    private func credentials() -> InMemoryCredentialStore {
        InMemoryCredentialStore(credentials: [account.id: "sk-test"])
    }
}
