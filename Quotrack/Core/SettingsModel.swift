import Foundation
import Observation

/// Owns the app-wide Settings state: the Polling Interval and the Launch at
/// Login toggle. The Account list stays with `AccountManager`. Login-item
/// status is always read back from the injected service, so System Settings
/// changes are reflected when Settings opens or the app activates.
@MainActor
@Observable
final class SettingsModel {
    private(set) var settings: AppSettings
    private(set) var launchAtLoginStatus: LoginItemStatus
    private(set) var loginItemErrorMessage: String?
    private(set) var settingsErrorMessage: String?

    @ObservationIgnored private let store: any SettingsStore
    @ObservationIgnored private let loginItemService: any LoginItemService

    /// Called after a Polling Interval change so the live monitor can apply it
    /// immediately instead of waiting out the previous interval.
    var onPollingIntervalChanged: (@MainActor (TimeInterval) -> Void)?

    init(store: any SettingsStore, loginItemService: any LoginItemService) {
        self.store = store
        self.loginItemService = loginItemService
        self.settings = store.loadSettings()
        self.launchAtLoginStatus = loginItemService.status
    }

    var pollingIntervalMinutes: Int {
        settings.pollingIntervalMinutes
    }

    var pollingInterval: TimeInterval {
        settings.pollingInterval
    }

    var isLaunchAtLoginEnabled: Bool {
        launchAtLoginStatus == .enabled
    }

    var requiresApproval: Bool {
        launchAtLoginStatus == .requiresApproval
    }

    /// Clamps, persists, and applies a new Polling Interval. An unchanged
    /// value is a no-op so opening Settings never rewrites the file.
    func setPollingInterval(minutes: Int) {
        let updated = AppSettings(pollingIntervalMinutes: minutes)
        guard updated != settings else {
            return
        }
        settings = updated
        do {
            try store.saveSettings(updated)
            settingsErrorMessage = nil
        } catch {
            settingsErrorMessage = error.localizedDescription
        }
        onPollingIntervalChanged?(updated.pollingInterval)
    }

    /// Enables or disables Launch at Login through the injected service and
    /// then re-reads the system status, which is the source of truth.
    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemErrorMessage = nil
        do {
            if enabled {
                try loginItemService.register()
            } else {
                try loginItemService.unregister()
            }
        } catch {
            loginItemErrorMessage = error.localizedDescription
        }
        refreshLoginItemStatus()
        if enabled, launchAtLoginStatus == .requiresApproval {
            loginItemService.openSystemSettingsLoginItems()
        }
    }

    func refreshLoginItemStatus() {
        launchAtLoginStatus = loginItemService.status
    }

    func openLoginItemsSettings() {
        loginItemService.openSystemSettingsLoginItems()
    }
}
