import AppKit
import SwiftUI

/// Hosts first-run onboarding in a regular window. Completion closes the
/// onboarding window and hands the saved Account back so the caller can reveal
/// the floating panel.
@MainActor
final class OnboardingWindowController {
    private let window: NSWindow
    private let onComplete: ((Account) -> Void)?

    init(model: OnboardingModel, onComplete: @escaping (Account) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = UIStrings.onboardingTitle
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(
            red: 0.055, green: 0.059, blue: 0.082, alpha: 1
        )
        window.center()
        self.window = window
        self.onComplete = onComplete

        window.contentView = NSHostingView(
            rootView: OnboardingView(model: model) { [weak self] in
                guard let self else {
                    return
                }
                self.window.orderOut(nil)
                if let account = model.completedAccount {
                    self.onComplete?(account)
                }
            }
        )
    }

    var isVisible: Bool {
        window.isVisible
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
