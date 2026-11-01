import Foundation

/// A deterministic ConnectionTesting fake. It records exactly what the
/// onboarding flow asked the Provider to verify and returns a chosen outcome.
final class RecordingConnectionTester: ConnectionTesting, @unchecked Sendable {
    struct Request: Equatable, Sendable {
        let provider: Provider
        let region: Region?
        let credential: String
    }

    private let lock = NSLock()
    private var remainingResults: [Result<BalanceSnapshot, BalanceProviderError>]
    private var recordedRequests: [Request] = []

    init(result: Result<BalanceSnapshot, BalanceProviderError>) {
        self.remainingResults = [result]
    }

    /// A sequence of outcomes, one consumed per call. The final outcome stays
    /// in place for any further calls.
    init(results: [Result<BalanceSnapshot, BalanceProviderError>]) {
        precondition(!results.isEmpty)
        self.remainingResults = results
    }

    var requests: [Request] {
        lock.withLock { recordedRequests }
    }

    func testConnection(
        provider: Provider,
        region: Region?,
        credential: String
    ) async throws -> BalanceSnapshot {
        let result: Result<BalanceSnapshot, BalanceProviderError> = lock.withLock {
            recordedRequests.append(
                Request(provider: provider, region: region, credential: credential)
            )
            return remainingResults.count > 1 ? remainingResults.removeFirst() : remainingResults[0]
        }
        return try result.get()
    }
}
