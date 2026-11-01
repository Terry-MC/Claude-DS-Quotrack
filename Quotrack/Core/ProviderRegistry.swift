/// Routes a Balance query to the adapter registered for the Account's
/// Provider. Real adapters and the mock adapter are both registered here, so
/// switching the data source never changes the monitor or the UI.
struct ProviderRegistry: BalanceProvider {
    static let supportedProviders = Provider.allCases

    private let adapters: [Provider: any BalanceProvider]

    init(adapters: [Provider: any BalanceProvider]) {
        self.adapters = adapters
    }

    func adapter(for provider: Provider) -> (any BalanceProvider)? {
        adapters[provider]
    }

    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        guard let adapter = adapters[account.provider] else {
            throw BalanceProviderError.unknown
        }
        return try await adapter.fetchBalance(for: account)
    }
}
