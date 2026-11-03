import Foundation

/// A deterministic ConnectionTesting fake. It records exactly what the
/// onboarding flow asked the Provider to verify and returns a chosen outcome.
final class RecordingConnectionTester: ConnectionTesting, @unchecked Sendable {
    struct Request: Equatable, Sendable {
        let draft: AccountDraft
    }

    private let lock = NSLock()
    private var remainingResults: [Result<AccountSnapshot, BalanceProviderError>]
    private var recordedRequests: [Request] = []

    init(result: Result<AccountSnapshot, BalanceProviderError>) {
        self.remainingResults = [result]
    }

    convenience init(balanceResult: Result<BalanceSnapshot, BalanceProviderError>) {
        self.init(result: balanceResult.map(AccountSnapshot.balance))
    }

    /// A sequence of outcomes, one consumed per call. The final outcome stays
    /// in place for any further calls.
    init(results: [Result<AccountSnapshot, BalanceProviderError>]) {
        precondition(!results.isEmpty)
        self.remainingResults = results
    }

    convenience init(balanceResults: [Result<BalanceSnapshot, BalanceProviderError>]) {
        self.init(results: balanceResults.map { $0.map(AccountSnapshot.balance) })
    }

    var requests: [Request] {
        lock.withLock { recordedRequests }
    }

    func testConnection(_ draft: AccountDraft) async throws -> AccountSnapshot {
        let result: Result<AccountSnapshot, BalanceProviderError> = lock.withLock {
            recordedRequests.append(Request(draft: draft))
            return remainingResults.count > 1 ? remainingResults.removeFirst() : remainingResults[0]
        }
        return try result.get()
    }
}
