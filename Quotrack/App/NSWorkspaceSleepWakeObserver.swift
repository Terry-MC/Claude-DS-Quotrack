import AppKit

/// Production sleep/wake source. NSWorkspace posts these notifications on the
/// main queue; the monitor consumes them to suspend and resume polling.
@MainActor
final class NSWorkspaceSleepWakeObserver: SleepWakeObserving {
    private let center: NotificationCenter
    private var tokens: [NSObjectProtocol] = []
    private var handler: (@MainActor (SleepWakeEvent) -> Void)?

    init(center: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.center = center
    }

    func start(on event: @escaping @MainActor (SleepWakeEvent) -> Void) {
        stop()
        handler = event
        let center = center
        tokens = [
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handler?(.willSleep)
                }
            },
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handler?(.didWake)
                }
            },
        ]
    }

    func stop() {
        handler = nil
        for token in tokens {
            center.removeObserver(token)
        }
        tokens.removeAll()
    }
}
