import AppKit
import Observation

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let monitor: any BalanceMonitor
    private let panelController: FloatingPanelController
    private let menuPresenter: StatusMenuPresenter
    private let interaction: MenuBarInteractionHandler
    private let menu: NSMenu
    private let settings: SettingsModel
    private let launchAtLoginItem: NSMenuItem
    var onOpenSettings: (() -> Void)?
    var onSwitchDataSource: (() -> Void)?

    init(
        monitor: any BalanceMonitor,
        settings: SettingsModel,
        onAddAccount: @escaping () -> Void = {}
    ) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let panelController = FloatingPanelController(
            monitor: monitor,
            onAddAccount: onAddAccount
        )
        let menu = NSMenu()
        let menuPresenter = StatusMenuPresenter(menu: menu)
        let launchAtLoginItem = NSMenuItem(
            title: UIStrings.launchAtLoginMenu,
            action: nil,
            keyEquivalent: ""
        )

        self.statusItem = statusItem
        self.monitor = monitor
        self.panelController = panelController
        self.menu = menu
        self.menuPresenter = menuPresenter
        self.settings = settings
        self.launchAtLoginItem = launchAtLoginItem
        self.interaction = MenuBarInteractionHandler(panel: panelController, menu: menuPresenter)

        super.init()

        configureStatusItem()
        configureMenu()
        menuPresenter.statusItem = statusItem
        menu.delegate = self
        updateLaunchAtLoginItemState()
        observeAggregateState()
    }

    /// Reveals the floating panel, used after onboarding completes.
    func showPanel() {
        panelController.show()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItem(for: monitor.aggregateState)
    }

    /// Re-registers after every change because Observation tracking fires
    /// once. Rows mutate on the main actor, so by the time the queued task
    /// runs the new aggregate is visible and can be applied to the icon.
    private func observeAggregateState() {
        withObservationTracking {
            updateStatusItem(for: monitor.aggregateState)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeAggregateState()
            }
        }
    }

    private func updateStatusItem(for state: AggregateBalanceState) {
        guard let button = statusItem.button else {
            return
        }
        let viewState = MenuBarStatusPresentation.viewState(for: state)
        let image = NSImage(
            systemSymbolName: viewState.symbolName,
            accessibilityDescription: viewState.accessibilityDescription
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = viewState.accessibilityDescription
    }

    private func configureMenu() {
        let settingsItem = menu.addItem(
            withTitle: "设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        #if DEBUG
        let switchDataSourceItem = menu.addItem(
            withTitle: "切换数据源（模拟/真实）",
            action: #selector(switchDataSource),
            keyEquivalent: ""
        )
        switchDataSourceItem.target = self
        #endif

        menu.addItem(.separator())

        let quitItem = menu.addItem(
            withTitle: "退出 Quotrack",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        interaction.handle(isRightClick ? .right : .left)
    }

    func menuWillOpen(_ menu: NSMenu) {
        settings.refreshLoginItemStatus()
        updateLaunchAtLoginItemState()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func toggleLaunchAtLogin() {
        settings.setLaunchAtLogin(!settings.isLaunchAtLoginEnabled)
        updateLaunchAtLoginItemState()
    }

    private func updateLaunchAtLoginItemState() {
        launchAtLoginItem.state = settings.isLaunchAtLoginEnabled ? .on : .off
    }

    @objc private func switchDataSource() {
        onSwitchDataSource?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
