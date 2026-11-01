import Foundation

/// Verifies a credential before an Account is saved. Onboarding depends on
/// this seam, so tests can prove success and failure without network access,
/// and mock mode can walk the same flow with fixtures.
protocol ConnectionTesting: Sendable {
    func testConnection(_ draft: AccountDraft) async throws -> BalanceSnapshot
}

/// The development adapter: it succeeds without a network request or a saved
/// Account, so the onboarding flow is usable in mock mode.
struct MockConnectionTester: ConnectionTesting {
    static let amount = Decimal(string: "42.50")!

    private let now: @Sendable () -> Date
    private let amount: Decimal

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        amount: Decimal = MockConnectionTester.amount
    ) {
        self.now = now
        self.amount = amount
    }

    func testConnection(_ draft: AccountDraft) async throws -> BalanceSnapshot {
        BalanceSnapshot(
            accountID: UUID(),
            balance: Balance(amount: amount, currency: .cny),
            fetchedAt: now(),
            isAvailable: true
        )
    }
}

/// The live test-connection implementation. Provider adapters are registered
/// here as they arrive; until then, an unregistered Provider reports an
/// unknown failure rather than a false success.
struct ProviderRegistryConnectionTester: ConnectionTesting {
    private let adapters: [Provider: any CredentialBalanceAdapter]

    init(adapters: [Provider: any CredentialBalanceAdapter]) {
        self.adapters = adapters
    }

    func testConnection(_ draft: AccountDraft) async throws -> BalanceSnapshot {
        guard let adapter = adapters[draft.provider] else {
            throw BalanceProviderError.unknown
        }
        return try await adapter.fetchBalance(
            region: draft.region,
            credential: draft.credential
        )
    }
}

extension ProviderRegistryConnectionTester {
    /// The production connection tester. It uses the same real adapters as the
    /// live registry, but sends the credential the user just entered rather
    /// than reading one from the Keychain.
    static func live(
        credentialStore: any CredentialStore,
        transport: any HTTPTransport = URLSessionTransport(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> ProviderRegistryConnectionTester {
        ProviderRegistryConnectionTester(
            adapters: LiveBalanceAdapters.make(
                credentialStore: credentialStore,
                transport: transport,
                now: now
            )
        )
    }
}
