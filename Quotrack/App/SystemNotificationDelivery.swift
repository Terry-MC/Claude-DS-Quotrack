import Foundation
import UserNotifications

/// Carries the first affected Account across process launches so clicking an
/// older Notification Center entry still reveals the right row after Quotrack
/// was quit and relaunched.
private enum NotificationUserInfoKey {
    static let accountID = "QuotrackAccountID"
}

/// Bridges the Core permission seam to UNUserNotificationCenter. The system
/// prompt appears only when a transition first needs delivery and the user has
/// not answered yet.
@MainActor
final class SystemNotificationAuthorizationProvider: NotificationAuthorizationProviding {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func permission() async -> NotificationPermission {
        let settings = await center.notificationSettings()
        return Self.permission(for: settings.authorizationStatus)
    }

    func requestPermission() async -> NotificationPermission {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound]
            )
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    static func permission(
        for status: UNAuthorizationStatus
    ) -> NotificationPermission {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }
}

/// Delivers one aggregated notification and routes a click back to its
/// Account. It is the notification center delegate so clicks work both while
/// the app is running and when a notification launches it.
@MainActor
final class SystemNotificationDeliverer: NSObject, NotificationDelivering {
    private let center: UNUserNotificationCenter
    private let openAccount: @MainActor (Account.ID) -> Void
    private var clickHandlers: [String: @MainActor () -> Void] = [:]

    init(
        center: UNUserNotificationCenter = .current(),
        openAccount: @escaping @MainActor (Account.ID) -> Void = { _ in }
    ) {
        self.center = center
        self.openAccount = openAccount
        super.init()
        center.delegate = self
    }

    func deliver(
        _ content: HealthNotificationContent,
        onOpen: @escaping @MainActor () -> Void
    ) async {
        let identifier = UUID().uuidString
        clickHandlers[identifier] = onOpen

        let notification = UNMutableNotificationContent()
        notification.title = content.title
        notification.body = content.body
        notification.sound = .default
        if let accountID = content.affectedAccountIDs.first {
            notification.userInfo = [
                NotificationUserInfoKey.accountID: accountID.uuidString,
            ]
        }
        let request = UNNotificationRequest(
            identifier: identifier,
            content: notification,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            clickHandlers[identifier] = nil
        }
    }
}

extension SystemNotificationDeliverer: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // The app is an accessory app; without this, a transition notification
        // would be silent while Quotrack is in the foreground.
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let accountID = (
            response.notification.request.content.userInfo[
                NotificationUserInfoKey.accountID
            ] as? String
        ).flatMap(UUID.init(uuidString:))
        Task { @MainActor [weak self] in
            if let handler = self?.clickHandlers.removeValue(forKey: identifier) {
                handler()
            } else if let accountID {
                // A notification from a previous launch has no in-memory
                // handler; the payload still names the Account to reveal.
                self?.openAccount(accountID)
            }
        }
        completionHandler()
    }
}
