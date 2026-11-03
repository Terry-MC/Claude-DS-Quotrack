import AppKit
import Observation
import SwiftUI

/// The right-edge dock: a borderless, non-activating panel that stays visible
/// while the main panel is hidden. All severity and badge decisions live in
/// `DockPresentation`; this controller only positions the panel, observes the
/// monitor, and forwards a click to the main panel.
@MainActor
final class DockPanelController {
    private let panel: DockPanel
    private let hostingView: DockHostingView
    private let monitor: any BalanceMonitor
    private let onOpenPanel: () -> Void
    private var presentation: DockPresentation
    private var isEnabled = false
    /// Observation tracking cannot be cancelled, so each registration carries
    /// a generation. A callback from before `hide()` or from an older
    /// registration stops instead of re-arming the chain.
    private var observationGeneration = 0
    private var screenObserver: (any NSObjectProtocol)?
    private var reduceMotionObserver: (any NSObjectProtocol)?

    init(
        monitor: any BalanceMonitor,
        onOpenPanel: @escaping () -> Void = {}
    ) {
        self.monitor = monitor
        self.onOpenPanel = onOpenPanel
        let size = DockFrameCalculator.defaultSize
        let presentation = DockPresentation.make(
            rows: monitor.rows,
            reduceMotion: Self.reduceMotionEnabled
        )
        let panel = DockPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.isMovable = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        let hostingView = DockHostingView(
            rootView: DockContentView(
                presentation: presentation,
                onOpen: onOpenPanel
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.setContentSize(size)
        panel.setAccessibilityLabel(presentation.accessibilityDescription)
        panel.setAccessibilityHelp(UIStrings.dockOpenPanelHint)
        self.panel = panel
        self.hostingView = hostingView
        self.presentation = presentation
    }

    /// Shows the dock without activating the app or making the panel key.
    func show() {
        if isEnabled {
            positionPanel()
            panel.orderFrontRegardless()
            return
        }
        isEnabled = true
        observeRows()
        startObservingSystemChanges()
        positionPanel()
        panel.orderFrontRegardless()
    }

    /// Removes the dock. Quitting calls this from `applicationWillTerminate`;
    /// `setEnabled(false)` is the seam for a future "dock off" preference.
    func hide() {
        isEnabled = false
        observationGeneration += 1
        panel.orderOut(nil)
        stopObservingSystemChanges()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            show()
        } else {
            hide()
        }
    }

    /// Observation follows `MenuBarController`: reading the monitor inside
    /// `withObservationTracking` registers exactly the rows the presentation
    /// depends on, and re-registers on the next main-actor turn.
    private func observeRows() {
        guard isEnabled else {
            return
        }
        observationGeneration += 1
        let generation = observationGeneration
        withObservationTracking {
            updatePresentation()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      self.isEnabled,
                      self.observationGeneration == generation else {
                    return
                }
                self.observeRows()
            }
        }
    }

    private func updatePresentation() {
        let updated = DockPresentation.make(
            rows: monitor.rows,
            reduceMotion: Self.reduceMotionEnabled
        )
        guard updated != presentation else {
            return
        }
        presentation = updated
        hostingView.rootView = DockContentView(
            presentation: updated,
            onOpen: onOpenPanel
        )
        panel.setAccessibilityLabel(updated.accessibilityDescription)
    }

    /// Places the dock at the right edge of the screen the app is working on,
    /// and moves it when displays are added, removed, or rearranged.
    private func positionPanel() {
        guard isEnabled else {
            return
        }
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard let frame = DockFrameCalculator.frame(
            for: DockFrameCalculator.defaultSize,
            in: visibleFrames,
            on: NSScreen.main?.visibleFrame
        ) else {
            panel.orderOut(nil)
            return
        }
        panel.setFrame(frame, display: true)
    }

    private func startObservingSystemChanges() {
        guard screenObserver == nil else {
            return
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.positionPanel()
            }
        }
        reduceMotionObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.observeRows()
            }
        }
    }

    private func stopObservingSystemChanges() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let reduceMotionObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(reduceMotionObserver)
        }
        screenObserver = nil
        reduceMotionObserver = nil
    }

    private static var reduceMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

/// A click on an inactive accessory app must reach the dock on the first
/// mouse-down, so the hosting view accepts first mouse.
private final class DockHostingView: NSHostingView<DockContentView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

/// A borderless panel that can never become key or main, so showing or
/// clicking the dock cannot steal keyboard focus from the frontmost app.
private final class DockPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
