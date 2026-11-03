import Foundation

/// The adapter seam the monitor uses. It returns whichever Metric the
/// Account's kind requires, so Balance and Quota Accounts share polling,
/// freshness, and persistence without sharing a response shape.
protocol AccountProvider: Sendable {
    func fetchSnapshot(for account: Account) async throws -> AccountSnapshot
}

/// Adapts a v1 Balance adapter to the multi-metric seam. Every balance
/// adapter keeps its existing request and parsing code.
struct BalanceProviderAdapter: AccountProvider {
    let provider: any BalanceProvider

    init(provider: any BalanceProvider) {
        self.provider = provider
    }

    func fetchSnapshot(for account: Account) async throws -> AccountSnapshot {
        .balance(try await provider.fetchBalance(for: account))
    }
}

/// The pre-save connection-test seam. A draft has no Account yet, so the
/// adapter receives the entered credential and the kind directly.
protocol CredentialAccountAdapter: Sendable {
    func fetchSnapshot(
        region: Region?,
        credential: String,
        kind: AccountKind
    ) async throws -> AccountSnapshot
}

/// Adapts a v1 credential-balance adapter to the connection-test seam.
struct BalanceCredentialAdapter: CredentialAccountAdapter {
    let adapter: any CredentialBalanceAdapter

    func fetchSnapshot(
        region: Region?,
        credential: String,
        kind: AccountKind
    ) async throws -> AccountSnapshot {
        .balance(
            try await adapter.fetchBalance(
                region: region,
                credential: credential
            )
        )
    }
}
