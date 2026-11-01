import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let panelController: FloatingPanelController
    private let menuPresenter: StatusMenuPresenter
    private let interaction: MenuBarInteractionHandler
    private let menu: NSMenu
    var onOpenSettings: (() -> Void)?
    var onSwitchDataSource: (() -> Void)?

    init(monitor: any BalanceMonitor) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let panelController = FloatingPanelController(monitor: monitor)
        let menu = NSMenu()
        let menuPresenter = StatusMenuPresenter(menu: menu)

        self.statusItem = statusItem
        self.panelController = panelController
        self.menu = menu
        self.menuPresenter = menuPresenter
        self.interaction = MenuBarInteractionHandler(panel: panelController, menu: menuPresenter)

        super.init()

        configureStatusItem()
        configureMenu()
        menuPresenter.statusItem = statusItem
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        let image = NSImage(
            systemSymbolName: "dollarsign.circle.fill",
            accessibilityDescription: "Quotrack"
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = "Quotrack"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        let settingsItem = menu.addItem(
            withTitle: "设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        let launchAtLoginItem = menu.addItem(
            withTitle: "开机启动",
            action: nil,
            keyEquivalent: ""
        )
        launchAtLoginItem.isEnabled = false

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

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func switchDataSource() {
        onSwitchDataSource?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
