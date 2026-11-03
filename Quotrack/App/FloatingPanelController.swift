import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: PanelPresenting {
    private let panel: NSPanel
    private let focus = PanelFocusModel()
    private let onDock: () -> Void
    private let onUndock: () -> Void
    private var moveObserver: (any NSObjectProtocol)?
    private var dragCheckTask: Task<Void, Never>?
    private var isProgrammaticMove = false
    private var isDocked = false

    init(
        monitor: any BalanceMonitor,
        onAddAccount: @escaping (Provider?) -> Void = { _ in },
        onOpenSettings: @escaping () -> Void = {},
        onDock: @escaping () -> Void = {},
        onUndock: @escaping () -> Void = {}
    ) {
        let contentSize = NSSize(
            width: UITheme.panelWidth,
            height: UITheme.panelHeight
        )
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
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
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 400, height: 480)
        let hostingView = NSHostingView(
            rootView: BalancePanelView(
                monitor: monitor,
                focus: focus,
                onAddAccount: onAddAccount,
                onOpenSettings: onOpenSettings,
                onClose: { [weak panel] in panel?.orderOut(nil) }
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: contentSize)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.setContentSize(contentSize)
        self.panel = panel
        self.onDock = onDock
        self.onUndock = onUndock
        restoreFrame(of: panel)
        observeMoves(of: panel)
    }

    /// Docking is triggered by the user's drag, not by a programmatic frame
    /// change. The check waits a beat after the last move and until the mouse
    /// is released, so the panel does not vanish mid-drag.
    private func observeMoves(of panel: NSPanel) {
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.panelDidMove()
            }
        }
    }

    private func panelDidMove() {
        guard !isProgrammaticMove, !isDocked, panel.isVisible else {
            return
        }
        dragCheckTask?.cancel()
        dragCheckTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(90))
            guard let self, !Task.isCancelled else {
                return
            }
            while NSEvent.pressedMouseButtons != 0 {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled {
                    return
                }
            }
            guard self.panel.isVisible,
                  let screen = self.panel.screen ?? NSScreen.main,
                  PanelDocking.shouldDock(
                    frame: self.panel.frame,
                    visibleFrame: screen.visibleFrame
                  ) else {
                return
            }
            self.dockPanel()
        }
    }

    private func dockPanel() {
        guard !isDocked else {
            return
        }
        isDocked = true
        dragCheckTask?.cancel()
        panel.orderOut(nil)
        onDock()
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
        if isDocked {
            isDocked = false
            if let screen = panel.screen ?? NSScreen.main {
                setFrameProgrammatically(
                    PanelDocking.restoreFrame(
                        panel.frame,
                        in: screen.visibleFrame
                    )
                )
            }
            onUndock()
        }
        panel.orderFrontRegardless()
    }

    /// Moves the window without making the move notification look like a user
    /// drag that should dock the panel again.
    private func setFrameProgrammatically(_ frame: CGRect) {
        isProgrammaticMove = true
        panel.setFrame(frame, display: true, animate: false)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            self?.isProgrammaticMove = false
        }
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
