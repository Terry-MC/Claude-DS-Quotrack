import AppKit
import SwiftUI

/// Hosts the full Settings window. It is a regular titled window, separate
/// from the always-on-top floating panel. Login-item status is re-read every
/// time the window opens so changes made in System Settings are reflected.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow
    private let settings: SettingsModel

    init(
        manager: AccountManager,
        settings: SettingsModel,
        onAccountsChanged: @escaping () -> Void = {}
    ) {
        let contentSize = NSSize(width: 560, height: 620)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quotrack 设置"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 520, height: 520)
        window.contentView = NSHostingView(
            rootView: SettingsView(
                manager: manager,
                settings: settings,
                onAccountsChanged: onAccountsChanged
            )
        )
        window.center()
        self.window = window
        self.settings = settings
    }

    func show() {
        settings.refreshLoginItemStatus()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
