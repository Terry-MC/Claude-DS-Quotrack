import Foundation

/// The Accounts and Provider adapter the monitor reads from. Mock mode swaps
/// this value while the monitor, UI, and refresh behavior stay real.
struct BalanceDataSource: Sendable {
    let accounts: [Account]
    let provider: any AccountProvider
}

extension BalanceDataSource {
    /// Live mode reads Account metadata from the injected store, so Accounts
    /// survive relaunch. Mock mode always uses fixtures and never reads or
    /// writes the real store.
    static func make(
        mode: DataSourceMode,
        now: Date = Date(),
        store: (any SnapshotStore)? = nil,
        credentialStore: any CredentialStore = KeychainCredentialStore(),
        transport: any HTTPTransport = URLSessionTransport()
    ) -> BalanceDataSource {
        switch mode {
        case .mock:
            return .mock(now: now, store: store)
        case .live:
            return BalanceDataSource(
                accounts: store?.loadAccounts() ?? [],
                provider: ProviderRegistry.live(
                    credentialStore: credentialStore,
                    transport: transport
                )
            )
        }
    }

    /// Mock mode: every addable Provider routes to the deterministic mock
    /// adapter. When a store is supplied, the panel reads the same Accounts
    /// Settings edits; otherwise it falls back to the fixture list. Legacy
    /// SiliconFlow fixtures stay in the list to exercise the unsupported state.
    static func mock(
        now: Date,
        store: (any SnapshotStore)? = nil
    ) -> BalanceDataSource {
        let fixtures = MockFixtures.standard(now: now)
        let quotaFixtures = MockFixtures.quotaFixtures(now: now)
        let mockProvider = BalanceProviderAdapter(
            provider: MockBalanceProvider(
                fixtures: fixtures,
                fallbackFetchedAt: now
            )
        )
        var adapters: [ProviderAdapterKey: any AccountProvider] = [:]
        for provider in Provider.addableCases {
            adapters[ProviderAdapterKey(provider: provider, kind: .balance)] = mockProvider
        }
        adapters[ProviderAdapterKey(provider: .moonshot, kind: .subscription)] =
            MockQuotaProvider(fixtures: quotaFixtures, now: now)
        let accounts = store?.loadAccounts()
            ?? fixtures.map(\.account) + quotaFixtures.map(\.account)
        return BalanceDataSource(
            accounts: accounts,
            provider: ProviderRegistry(adapters: adapters)
        )
    }
}
