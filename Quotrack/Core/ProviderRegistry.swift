import Foundation

/// Identifies one Provider adapter. A Provider can expose more than one
/// Account Kind, so the kind is part of the routing key.
struct ProviderAdapterKey: Hashable, Sendable {
    let provider: Provider
    let kind: AccountKind
}

/// Routes a snapshot query to the adapter registered for the Account's
/// Provider and kind. Real adapters and the mock adapter are both registered
/// here, so switching the data source never changes the monitor or the UI.
struct ProviderRegistry: AccountProvider {
    private let adapters: [ProviderAdapterKey: any AccountProvider]

    init(adapters: [ProviderAdapterKey: any AccountProvider]) {
        self.adapters = adapters
    }

    func fetchSnapshot(for account: Account) async throws -> AccountSnapshot {
        let key = ProviderAdapterKey(provider: account.provider, kind: account.kind)
        guard let adapter = adapters[key] else {
            throw BalanceProviderError.unsupportedAccountKind
        }
        return try await adapter.fetchSnapshot(for: account)
    }
}

extension ProviderRegistry {
    /// The production registry. Providers whose adapters are not implemented
    /// yet are absent, so the registry fails them with a typed error rather
    /// than showing fabricated data.
    static func live(
        credentialStore: any CredentialStore,
        transport: any HTTPTransport = URLSessionTransport(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> ProviderRegistry {
        let balanceAdapters = LiveBalanceAdapters.make(
            credentialStore: credentialStore,
            transport: transport,
            now: now
        )
        var adapters: [ProviderAdapterKey: any AccountProvider] = [:]
        for (provider, adapter) in balanceAdapters {
            adapters[ProviderAdapterKey(provider: provider, kind: .balance)] =
                BalanceProviderAdapter(provider: adapter)
        }
        adapters[ProviderAdapterKey(provider: .moonshot, kind: .subscription)] =
            KimiCodeAdapter(
                transport: transport,
                credentialStore: credentialStore,
                now: now
            )
        return ProviderRegistry(adapters: adapters)
    }
}
