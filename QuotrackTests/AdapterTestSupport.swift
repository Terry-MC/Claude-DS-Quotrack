import Foundation
import Testing

/// Fetches through a Provider adapter and returns the typed failure. Shared by
/// the adapter suites so a new adapter does not copy the error plumbing.
func providerError<Adapter: BalanceProvider>(
    from adapter: Adapter,
    account: Account
) async -> BalanceProviderError {
    do {
        _ = try await adapter.fetchBalance(for: account)
        Issue.record("Expected the fetch to fail, but it succeeded.")
        return .unknown
    } catch let error as BalanceProviderError {
        return error
    } catch {
        Issue.record("Expected a typed Provider error, got \(error).")
        return .unknown
    }
}
