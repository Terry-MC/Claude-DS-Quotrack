/// System power events that pause and resume automatic polling.
enum SleepWakeEvent: Sendable, Equatable {
    case willSleep
    case didWake
}

/// The seam between the monitor and system sleep/wake notifications.
/// Production observes NSWorkspace; tests send events through a fake.
@MainActor
protocol SleepWakeObserving: AnyObject {
    func start(on event: @escaping @MainActor (SleepWakeEvent) -> Void)
    func stop()
}

/// A publisher that never sends events, used when no observer is injected.
@MainActor
final class NoopSleepWakeObserver: SleepWakeObserving {
    func start(on event: @escaping @MainActor (SleepWakeEvent) -> Void) {}
    func stop() {}
}
