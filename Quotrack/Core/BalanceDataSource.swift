import Foundation

/// The Accounts and Provider adapter the monitor reads from. Mock mode swaps
/// this value while the monitor, UI, and refresh behavior stay real.
struct BalanceDataSource: Sendable {
    let accounts: [Account]
    let provider: any BalanceProvider
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
            return .mock(now: now)
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

    /// Mock mode: every supported Provider routes to the deterministic mock
    /// adapter, and the Accounts come from the same fixture set.
    static func mock(now: Date) -> BalanceDataSource {
        let fixtures = MockFixtures.standard(now: now)
        let mockProvider = MockBalanceProvider(fixtures: fixtures)
        let registry = ProviderRegistry(
            adapters: Dictionary(
                uniqueKeysWithValues: Provider.allCases.map { ($0, mockProvider) }
            )
        )
        return BalanceDataSource(
            accounts: fixtures.map(\.account),
            provider: registry
        )
    }
}
