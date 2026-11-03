import Foundation

/// The system notification permission relevant to delivery. `provisional` and
/// `ephemeral` authorizations are mapped to `authorized` by the App adapter.
enum NotificationPermission: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

/// Supplies the current notification permission and asks the user when it has
/// not been decided yet. The App adapter wraps UNUserNotificationCenter; tests
/// inject a fake.
@MainActor
protocol NotificationAuthorizationProviding: AnyObject {
    func permission() async -> NotificationPermission
    func requestPermission() async -> NotificationPermission
}

/// Delivers one aggregated notification through the system Notification
/// Center. The click action is supplied per delivery so a notification can
/// reveal the Account it refers to.
@MainActor
protocol NotificationDelivering: AnyObject {
    func deliver(
        _ content: HealthNotificationContent,
        onOpen: @escaping @MainActor () -> Void
    ) async
}

/// The in-app fallback shown when notification permission is denied. It must
/// work without Notification Center and disappear after a short time.
@MainActor
protocol HealthToastPresenting: AnyObject {
    func show(
        _ content: HealthNotificationContent,
        onOpen: @escaping @MainActor () -> Void
    )
}

/// The monitor's notification seam. It is called once after every completed
/// refresh, never per row.
@MainActor
protocol HealthNotificationSink: AnyObject {
    func pollDidComplete(rows: [BalanceRow])
}

/// Display-ready contents of one aggregated Health notification. Both the
/// system notification and the in-app toast render the same value.
struct HealthNotificationContent: Equatable, Sendable {
    let title: String
    let body: String
    /// The worst destination state in the batch, used for the toast's icon.
    let severity: AccountHealth
    /// In panel order, so the first entry is the Account a click reveals.
    let affectedAccountIDs: [Account.ID]
}

enum HealthNotificationPresentation {
    /// Builds one notification for the whole batch. A recovery-only batch gets
    /// the recovery title; a mixed or worsening batch gets the alert title.
    static func content(
        for batch: HealthNotificationBatch
    ) -> HealthNotificationContent? {
        guard !batch.isEmpty else {
            return nil
        }
        let transitions = batch.transitions
        let isRecoveryOnly = transitions.allSatisfy { $0.to < $0.from }
        let title = isRecoveryOnly
            ? UIStrings.healthRecoveryNotificationTitle
            : UIStrings.healthNotificationTitle
        let lines = transitions.map { transition in
            "\(transition.provider.displayName) · \(transition.label)："
                + "\(transition.from.displayText) → \(transition.to.displayText)"
        }
        let body: String
        if transitions.count == 1, let line = lines.first {
            body = line
        } else {
            body = (
                [UIStrings.healthNotificationSummary(count: transitions.count)]
                    + lines
            ).joined(separator: "\n")
        }
        return HealthNotificationContent(
            title: title,
            body: body,
            severity: transitions.map(\.to).max() ?? .normal,
            affectedAccountIDs: transitions.map(\.accountID)
        )
    }
}

/// Detects transitions after each poll and routes the aggregated notification
/// to Notification Center or the in-app toast. The class has no
/// UserNotifications or AppKit dependency, so tests can drive every route with
/// fakes and never schedule a real notification.
@MainActor
final class HealthNotificationCoordinator: HealthNotificationSink {
    private var detector = HealthTransitionDetector()
    private let authorization: any NotificationAuthorizationProviding
    private let notificationDeliverer: any NotificationDelivering
    private let toastPresenter: any HealthToastPresenting
    private let openAccount: @MainActor (Account.ID) -> Void
    /// The in-flight delivery for the latest batch. Exposed so tests can await
    /// the routing and delivery deterministically.
    private(set) var deliveryTask: Task<Void, Never>?

    init(
        authorization: any NotificationAuthorizationProviding,
        notificationDeliverer: any NotificationDelivering,
        toastPresenter: any HealthToastPresenting,
        openAccount: @escaping @MainActor (Account.ID) -> Void
    ) {
        self.authorization = authorization
        self.notificationDeliverer = notificationDeliverer
        self.toastPresenter = toastPresenter
        self.openAccount = openAccount
    }

    func pollDidComplete(rows: [BalanceRow]) {
        let batch = detector.observe(rows: rows)
        guard let content = HealthNotificationPresentation.content(for: batch),
              let firstAccountID = batch.firstAffectedAccountID else {
            deliveryTask = nil
            return
        }
        deliveryTask = Task { [weak self] in
            await self?.deliver(content, focusing: firstAccountID)
        }
    }

    private func deliver(
        _ content: HealthNotificationContent,
        focusing accountID: Account.ID
    ) async {
        var permission = await authorization.permission()
        if permission == .notDetermined {
            permission = await authorization.requestPermission()
        }
        let onOpen: @MainActor () -> Void = { [openAccount] in
            openAccount(accountID)
        }
        switch permission {
        case .authorized:
            await notificationDeliverer.deliver(content, onOpen: onOpen)
        case .denied, .notDetermined:
            toastPresenter.show(content, onOpen: onOpen)
        }
    }
}
