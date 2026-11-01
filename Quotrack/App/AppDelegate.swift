import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var monitor: LiveBalanceMonitor?
    private var store: (any SnapshotStore)?
    private var accountManager: AccountManager?
    private var settingsWindowController: SettingsWindowController?
    private var dataSourceMode = DataSourceMode.live

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        dataSourceMode = LaunchOptions
            .parse(arguments: ProcessInfo.processInfo.arguments)
            .dataSourceMode
        let store = FileSnapshotStore.applicationSupport()
        self.store = store
        let accountManager = AccountManager(
            store: store,
            credentialStore: KeychainCredentialStore()
        )
        self.accountManager = accountManager
        let monitor = LiveBalanceMonitor(
            dataSource: BalanceDataSource.make(mode: dataSourceMode, store: store),
            store: dataSourceMode == .live ? store : nil,
            sleepWakeObserver: NSWorkspaceSleepWakeObserver()
        )
        self.monitor = monitor

        let menuBarController = MenuBarController(monitor: monitor)
        menuBarController.onOpenSettings = { [weak self] in
            self?.showSettings()
        }
        menuBarController.onSwitchDataSource = { [weak self] in
            self?.toggleDataSource()
        }
        self.menuBarController = menuBarController

        monitor.startPolling()
        Task { await monitor.refresh() }
    }

    private func showSettings() {
        guard let accountManager else {
            return
        }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(manager: accountManager)
        }
        settingsWindowController?.show()
    }

    private func toggleDataSource() {
        dataSourceMode = dataSourceMode.toggled
        guard let monitor else {
            return
        }
        let dataSource = BalanceDataSource.make(mode: dataSourceMode, store: store)
        let persistence = dataSourceMode == .live ? store : nil
        Task { await monitor.switchDataSource(dataSource, store: persistence) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
