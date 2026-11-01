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
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = UIStrings.onboardingTitle
        window.isReleasedWhenClosed = false
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
