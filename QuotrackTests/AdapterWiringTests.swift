import Foundation
import Testing

/// Proves every real adapter is reachable through all three production seams:
/// the live Provider registry, the live data source the monitor polls, and the
/// onboarding/Settings connection tester. The case table is parameterized so a
/// new adapter is added once instead of copied into four near-identical files.
struct AdapterWiringTests {
    @Test(arguments: wiringCases)
    func theLiveRegistryRoutesProviderAccountsToTheRealAdapter(
        _ wiring: WiringCase
    ) async throws {
        let transport = StubHTTPTransport(
            response: .json(body: wiring.fixture)
        )
        let registry = ProviderRegistry.live(
            credentialStore: credentials(for: wiring),
            transport: transport,
            now: { wiring.now }
        )

        let snapshot = try await registry.fetchBalance(for: wiring.account)

        #expect(snapshot.balance == wiring.expectedBalance)
        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.url == wiring.expectedEndpoint)
        #expect(
            request.headers["Authorization"]
                == "Bearer \(wiring.storedCredential)"
        )
    }

    @Test(arguments: wiringCases)
    @MainActor
    func theLiveDataSourceLoadsAccountsAndPollsThemThroughTheRealAdapter(
        _ wiring: WiringCase
    ) async {
        let transport = StubHTTPTransport(
            response: .json(body: wiring.fixture)
        )
        let store = InMemorySnapshotStore(accounts: [wiring.account])
        let dataSource = BalanceDataSource.make(
            mode: .live,
            store: store,
            credentialStore: credentials(for: wiring),
            transport: transport
        )

        #expect(dataSource.accounts == [wiring.account])

        let monitor = LiveBalanceMonitor(
            dataSource: dataSource,
            pollingInterval: 300,
            now: { wiring.now }
        )
        await monitor.refresh()

        #expect(
            monitor.rows.first?.snapshot?.balance
                == wiring.expectedBalance
        )
        #expect(transport.requests.first?.url == wiring.expectedEndpoint)
    }

    @Test(arguments: wiringCases)
    func theLiveConnectionTesterSendsTheEnteredCredentialToTheRealAdapter(
        _ wiring: WiringCase
    ) async throws {
        let transport = StubHTTPTransport(
            response: .json(body: wiring.fixture)
        )
        let tester = ProviderRegistryConnectionTester.live(
            credentialStore: InMemoryCredentialStore(),
            transport: transport,
            now: { wiring.now }
        )

        let snapshot = try await tester.testConnection(
            AccountDraft(
                provider: wiring.account.provider,
                region: wiring.account.region,
                label: wiring.account.label,
                credential: wiring.enteredCredential
            )
        )

        #expect(snapshot.balance == wiring.expectedBalance)
        #expect(snapshot.isAvailable)
        let request = try #require(transport.requests.first)
        #expect(request.url == wiring.expectedEndpoint)
        #expect(
            request.headers["Authorization"]
                == "Bearer \(wiring.enteredCredential)"
        )
    }

    @Test
    func providersWithoutAnAdapterStillFailHonestly() async {
        let registry = ProviderRegistry(adapters: [:])
        let account = Account(id: UUID(), provider: .moonshot, label: "Kimi")

        await #expect(throws: BalanceProviderError.unknown) {
            try await registry.fetchBalance(for: account)
        }
    }
}

/// One Provider's fixture, Account, and expected request destination. Region
/// variants are separate cases because the endpoint and currency differ.
struct WiringCase: Sendable, CustomTestStringConvertible {
    let name: String
    let account: Account
    let storedCredential: String
    let enteredCredential: String
    let fixture: String
    let expectedBalance: Balance
    let expectedEndpoint: URL
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    var testDescription: String { name }
}

private let wiringCases: [WiringCase] = [
    WiringCase(
        name: "DeepSeek",
        account: Account(id: UUID(), provider: .deepSeek, label: "个人账户"),
        storedCredential: "sk-test",
        enteredCredential: "sk-entered",
        fixture: DeepSeekFixtures.success,
        expectedBalance: Balance(
            amount: Decimal(string: "110.00")!,
            currency: .cny
        ),
        expectedEndpoint: DeepSeekAdapter.endpoint
    ),
    WiringCase(
        name: "Moonshot 国内",
        account: Account(
            id: UUID(),
            provider: .moonshot,
            region: .domestic,
            label: "Kimi 国内"
        ),
        storedCredential: "sk-moonshot",
        enteredCredential: "sk-entered",
        fixture: MoonshotFixtures.success,
        expectedBalance: Balance(
            amount: Decimal(string: "49.58894")!,
            currency: .cny
        ),
        expectedEndpoint: MoonshotAdapter.domesticEndpoint
    ),
    WiringCase(
        name: "Moonshot 国际",
        account: Account(
            id: UUID(),
            provider: .moonshot,
            region: .international,
            label: "Kimi 国际"
        ),
        storedCredential: "sk-international",
        enteredCredential: "sk-entered",
        fixture: MoonshotFixtures.success,
        expectedBalance: Balance(
            amount: Decimal(string: "49.58894")!,
            currency: .usd
        ),
        expectedEndpoint: MoonshotAdapter.internationalEndpoint
    ),
    WiringCase(
        name: "SiliconFlow 国内",
        account: Account(
            id: UUID(),
            provider: .siliconFlow,
            region: .domestic,
            label: "硅基流动"
        ),
        storedCredential: "sk-test",
        enteredCredential: "sk-entered",
        fixture: SiliconFlowFixtures.domesticSuccess,
        expectedBalance: Balance(
            amount: Decimal(string: "88.88")!,
            currency: .cny
        ),
        expectedEndpoint: SiliconFlowAdapter.domesticEndpoint
    ),
    WiringCase(
        name: "SiliconFlow 国际",
        account: Account(
            id: UUID(),
            provider: .siliconFlow,
            region: .international,
            label: "SiliconFlow Global"
        ),
        storedCredential: "sk-global",
        enteredCredential: "sk-entered",
        fixture: SiliconFlowFixtures.internationalSuccess,
        expectedBalance: Balance(
            amount: Decimal(string: "25.00")!,
            currency: .usd
        ),
        expectedEndpoint: SiliconFlowAdapter.internationalEndpoint
    ),
    WiringCase(
        name: "OpenRouter",
        account: Account(id: UUID(), provider: .openRouter, label: "管理账户"),
        storedCredential: "sk-or-management",
        enteredCredential: "sk-or-entered",
        fixture: OpenRouterFixtures.success,
        expectedBalance: Balance(
            amount: Decimal(string: "74.75")!,
            currency: .usd
        ),
        expectedEndpoint: OpenRouterAdapter.endpoint
    ),
]

private func credentials(for wiring: WiringCase) -> InMemoryCredentialStore {
    InMemoryCredentialStore(
        credentials: [wiring.account.id: wiring.storedCredential]
    )
}
