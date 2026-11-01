import AppKit
import SwiftUI

/// Hosts the minimal Settings window. It is a regular titled window, separate
/// from the always-on-top floating panel.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(manager: AccountManager) {
        let contentSize = NSSize(width: 520, height: 380)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quotrack 设置"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 460, height: 320)
        window.contentView = NSHostingView(
            rootView: SettingsView(manager: manager)
        )
        window.center()
        self.window = window
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
