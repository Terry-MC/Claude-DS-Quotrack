import Foundation

/// Caps how many Provider fetches are in flight at once. The monitor owns one
/// limiter, so the cap is global across polling and manual refreshes rather
/// than per refresh call.
actor FetchLimiter {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private var available: Int
    private var waiters: [Waiter] = []

    init(capacity: Int) {
        precondition(capacity > 0, "A fetch limiter needs at least one slot")
        self.available = capacity
    }

    /// Takes a slot, waiting until one frees up. Throws `CancellationError` if
    /// the caller is cancelled while waiting, in which case no slot is held.
    func acquire() async throws {
        if available > 0 {
            available -= 1
            return
        }

        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    /// Frees the slot, handing it directly to the next waiter when one exists.
    func release() {
        guard !waiters.isEmpty else {
            available += 1
            return
        }
        let waiter = waiters.removeFirst()
        waiter.continuation.resume()
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
