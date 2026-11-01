import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var monitor: LiveBalanceMonitor?
    private var store: (any SnapshotStore)?
    private var accountManager: AccountManager?
    private var settingsModel: SettingsModel?
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
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
        let settingsModel = SettingsModel(
            store: FileSettingsStore(directoryURL: store.directoryURL),
            loginItemService: SMAppServiceLoginItemService()
        )
        self.settingsModel = settingsModel

        let monitor = LiveBalanceMonitor(
            dataSource: BalanceDataSource.make(mode: dataSourceMode, store: store),
            store: dataSourceMode == .live ? store : nil,
            pollingInterval: settingsModel.pollingInterval,
            sleepWakeObserver: NSWorkspaceSleepWakeObserver()
        )
        self.monitor = monitor
        settingsModel.onPollingIntervalChanged = { [weak monitor] interval in
            monitor?.pollingInterval = interval
        }

        let menuBarController = MenuBarController(
            monitor: monitor,
            settings: settingsModel,
            onAddAccount: { [weak self] in self?.showOnboarding() }
        )
        menuBarController.onOpenSettings = { [weak self] in
            self?.showSettings()
        }
        menuBarController.onSwitchDataSource = { [weak self] in
            self?.toggleDataSource()
        }
        self.menuBarController = menuBarController

        monitor.startPolling()
        Task { await monitor.refresh() }

        // A fresh install has no Accounts, so onboarding replaces the useful
        // but empty panel. Once an Account is saved the panel is revealed.
        if accountManager.accounts.isEmpty {
            showOnboarding()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        settingsModel?.refreshLoginItemStatus()
    }

    private func showSettings() {
        guard let accountManager, let settingsModel else {
            return
        }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                manager: accountManager,
                settings: settingsModel,
                onAccountsChanged: { [weak self] in self?.reloadMonitorAccounts() }
            )
        }
        settingsWindowController?.show()
    }

    private func showOnboarding() {
        if let onboardingWindowController, onboardingWindowController.isVisible {
            return
        }
        guard let accountManager else {
            return
        }
        let model = OnboardingModel(
            accountManager: accountManager,
            connectionTester: makeConnectionTester()
        )
        let controller = OnboardingWindowController(model: model) { [weak self] _ in
            guard let self else {
                return
            }
            self.onboardingWindowController = nil
            self.reloadMonitorAccounts()
            self.menuBarController?.showPanel()
        }
        onboardingWindowController = controller
        controller.show()
    }

    /// Development builds walk onboarding against the mock adapter; live
    /// adapters register here as they are implemented, so an unregistered
    /// Provider fails honestly instead of claiming success.
    private func makeConnectionTester() -> any ConnectionTesting {
        switch dataSourceMode {
        case .mock:
            MockConnectionTester()
        case .live:
            ProviderRegistryConnectionTester(adapters: [:])
        }
    }

    /// Account CRUD changes the Account list, so the monitor re-reads its data
    /// source and refreshes rather than waiting for a relaunch.
    private func reloadMonitorAccounts() {
        guard let monitor, let store else {
            return
        }
        let dataSource = BalanceDataSource.make(mode: dataSourceMode, store: store)
        let persistence = dataSourceMode == .live ? store : nil
        Task {
            await monitor.switchDataSource(dataSource, store: persistence)
        }
    }

    private func toggleDataSource() {
        dataSourceMode = dataSourceMode.toggled
        reloadMonitorAccounts()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
