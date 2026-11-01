import Foundation

/// The time seam the monitor polls against. A custom protocol, rather than
/// `Clock`, because an existential `Clock` can read `now` but cannot sleep;
/// tests substitute a clock that only moves when advanced.
protocol PollingClock: Sendable {
    var now: Date { get }
    func sleep(for duration: Duration) async throws
}

/// The production clock: wall time and the system sleep mechanism.
struct SystemPollingClock: PollingClock {
    var now: Date { Date() }

    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
