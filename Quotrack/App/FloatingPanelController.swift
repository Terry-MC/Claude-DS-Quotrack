import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: PanelPresenting {
    private let panel: NSPanel
    private let focus = PanelFocusModel()

    init(
        monitor: any BalanceMonitor,
        onAddAccount: @escaping () -> Void = {}
    ) {
        let contentSize = NSSize(width: 360, height: 420)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Quotrack"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        let hostingView = NSHostingView(
            rootView: BalancePanelView(
                monitor: monitor,
                focus: focus,
                onAddAccount: onAddAccount
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: contentSize)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.setContentSize(contentSize)
        self.panel = panel
        restoreFrame(of: panel)
    }

    /// Restores the last position instead of centering on every launch. A
    /// saved frame that is still on a display is clamped inside that display's
    /// visible frame; a frame from a disconnected display is centered.
    private func restoreFrame(of panel: NSPanel) {
        panel.setFrameAutosaveName(PanelFrameMemory.autosaveName)
        guard panel.setFrameUsingName(PanelFrameMemory.autosaveName) else {
            center(panel)
            return
        }
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        if let clamped = PanelFrameMemory.clamped(panel.frame, to: visibleFrames) {
            panel.setFrame(clamped, display: false)
        } else {
            center(panel)
        }
    }

    private func center(_ panel: NSPanel) {
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            panel.center()
            return
        }
        panel.setFrame(
            PanelFrameMemory.centered(size: panel.frame.size, in: visibleFrame),
            display: false
        )
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show() {
        panel.orderFrontRegardless()
    }

    /// Reveals the panel and requests that the first affected Account row be
    /// expanded and scrolled into view. The request survives a hidden panel
    /// because the hosting view is already mounted.
    func show(focusing accountID: Account.ID) {
        focus.focus(accountID)
        show()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
