import Foundation

/// A fake Provider for monitor tests. It records which Accounts were fetched,
/// how many fetches are in flight at once, and lets a test wait for fetch
/// milestones without polling wall-clock time.
final class RecordingBalanceProvider: BalanceProvider, @unchecked Sendable {
    typealias Handler = @Sendable (Account) async throws -> BalanceSnapshot

    private let lock = NSLock()
    private let handler: Handler
    private var startedAccountIDs: [Account.ID] = []
    private var activeFetches = 0
    private var peakFetches = 0
    private var finishedFetches = 0
    private var startWaiters: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var finishWaiters: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    convenience init(snapshot: @escaping @Sendable (Account) -> BalanceSnapshot) {
        self.init(handler: { account in snapshot(account) })
    }

    var fetchedAccountIDs: [Account.ID] {
        lock.withLock { startedAccountIDs }
    }

    var startedCount: Int {
        lock.withLock { startedAccountIDs.count }
    }

    var finishedCount: Int {
        lock.withLock { finishedFetches }
    }

    var peakConcurrentFetches: Int {
        lock.withLock { peakFetches }
    }

    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        let startContinuations = lock.withLock {
            startedAccountIDs.append(account.id)
            activeFetches += 1
            peakFetches = max(peakFetches, activeFetches)
            return takeSatisfiedWaiters(&startWaiters, expected: startedAccountIDs.count)
        }
        for continuation in startContinuations {
            continuation.resume()
        }

        defer {
            let finishContinuations = lock.withLock {
                activeFetches -= 1
                finishedFetches += 1
                return takeSatisfiedWaiters(&finishWaiters, expected: finishedFetches)
            }
            for continuation in finishContinuations {
                continuation.resume()
            }
        }

        return try await handler(account)
    }

    /// Waits until this many fetches have started.
    func waitForStartedCount(_ expected: Int) async {
        let needsWait = lock.withLock { startedAccountIDs.count < expected }
        guard needsWait else {
            return
        }
        await withCheckedContinuation { continuation in
            let alreadySatisfied = lock.withLock {
                if startedAccountIDs.count >= expected {
                    return true
                }
                startWaiters.append((expected, continuation))
                return false
            }
            if alreadySatisfied {
                continuation.resume()
            }
        }
    }

    /// Waits until this many fetches have finished.
    func waitForFinishedCount(_ expected: Int) async {
        let needsWait = lock.withLock { finishedFetches < expected }
        guard needsWait else {
            return
        }
        await withCheckedContinuation { continuation in
            let alreadySatisfied = lock.withLock {
                if finishedFetches >= expected {
                    return true
                }
                finishWaiters.append((expected, continuation))
                return false
            }
            if alreadySatisfied {
                continuation.resume()
            }
        }
    }

    /// Must be called with the lock held. The caller resumes the continuations
    /// after unlocking.
    private func takeSatisfiedWaiters(
        _ waiters: inout [(expected: Int, continuation: CheckedContinuation<Void, Never>)],
        expected: Int
    ) -> [CheckedContinuation<Void, Never>] {
        let satisfied = waiters.filter { $0.expected <= expected }
        waiters.removeAll { $0.expected <= expected }
        return satisfied.map(\.continuation)
    }
}

/// A gate whose `wait()` suspends until the test opens it. It gives the
/// concurrency test a deterministic way to hold fetches in flight.
actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        guard !isOpen else {
            return
        }
        isOpen = true
        let continuations = waiters
        waiters.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }
}
