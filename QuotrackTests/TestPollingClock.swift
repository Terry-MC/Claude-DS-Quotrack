import Foundation

/// A deterministic poll clock for tests. `now` moves only when the test
/// advances it, and each sleep resolves from `advance(by:)`, so polling
/// schedules are exercised without wall-clock time.
final class TestPollingClock: PollingClock, @unchecked Sendable {
    private struct Sleeper {
        let id: UUID
        let deadline: Date
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var currentDate: Date
    private var sleepers: [Sleeper] = []
    private var registeredSleepCount = 0
    private var sleepCountWaiters: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(now: Date) {
        self.currentDate = now
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return currentDate
    }

    var sleepCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return registeredSleepCount
    }

    /// The earliest deadline any pending sleep will resolve at. Lets tests
    /// assert a backoff or staleness schedule without driving the clock.
    var nextSleepDeadline: Date? {
        lock.lock()
        defer { lock.unlock() }
        return sleepers.map(\.deadline).min()
    }

    func sleep(for duration: Duration) async throws {
        let deadline = now.addingTimeInterval(duration.timeInterval)
        let id = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if Task.isCancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                registeredSleepCount += 1
                let waiters = takeSatisfiedSleepWaiters()
                lock.unlock()
                for waiter in waiters {
                    waiter.resume()
                }
            }
        } onCancel: {
            self.cancelSleep(id)
        }
    }

    /// Moves time forward, resolving every sleep whose deadline has been
    /// reached. Runs are resumed outside the lock so a resumed sleeper can
    /// re-enter the clock immediately.
    func advance(by interval: TimeInterval) {
        lock.lock()
        currentDate = currentDate.addingTimeInterval(interval)
        let due = sleepers.filter { $0.deadline <= currentDate }
        sleepers.removeAll { $0.deadline <= currentDate }
        lock.unlock()

        for sleeper in due {
            sleeper.continuation.resume()
        }
    }

    /// Waits until at least `expected` sleeps have been registered, including
    /// sleeps that were registered before this call.
    func waitForSleepCount(_ expected: Int) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if registeredSleepCount >= expected {
                lock.unlock()
                continuation.resume()
            } else {
                sleepCountWaiters.append((expected, continuation))
                lock.unlock()
            }
        }
    }

    private func takeSatisfiedSleepWaiters() -> [CheckedContinuation<Void, Never>] {
        let satisfied = sleepCountWaiters.filter { $0.expected <= registeredSleepCount }
        sleepCountWaiters.removeAll { $0.expected <= registeredSleepCount }
        return satisfied.map(\.continuation)
    }

    private func cancelSleep(_ id: UUID) {
        lock.lock()
        guard let index = sleepers.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        let sleeper = sleepers.remove(at: index)
        lock.unlock()
        sleeper.continuation.resume(throwing: CancellationError())
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
