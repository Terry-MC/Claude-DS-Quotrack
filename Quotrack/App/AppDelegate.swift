import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var monitor: LiveBalanceMonitor?
    private var healthNotificationCoordinator: HealthNotificationCoordinator?
    private var store: (any SnapshotStore)?
    private var accountManager: AccountManager?
    private var settingsModel: SettingsModel?
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var dataSourceMode = DataSourceMode.live
    /// One Keychain store and one HTTP transport are shared by Account CRUD,
    /// the live Provider registry, and the onboarding connection tester, so all
    /// three paths read and send credentials the same way.
    private var credentialStore: (any CredentialStore)?
    private var transport: (any HTTPTransport)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        dataSourceMode = LaunchOptions
            .parse(arguments: ProcessInfo.processInfo.arguments)
            .dataSourceMode
        let store = FileSnapshotStore.applicationSupport()
        self.store = store
        let credentialStore = KeychainCredentialStore()
        self.credentialStore = credentialStore
        let transport = URLSessionTransport()
        self.transport = transport
        let accountManager = AccountManager(
            store: store,
            credentialStore: credentialStore
        )
        self.accountManager = accountManager
        let settingsModel = SettingsModel(
            store: FileSettingsStore(directoryURL: store.directoryURL),
            loginItemService: SMAppServiceLoginItemService()
        )
        self.settingsModel = settingsModel

        let monitor = LiveBalanceMonitor(
            dataSource: BalanceDataSource.make(
                mode: dataSourceMode,
                store: store,
                credentialStore: credentialStore,
                transport: transport
            ),
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

        // Health notifications are computed once per completed poll. A system
        // notification is used when permission is granted; a denied prompt
        // falls back to the in-app toast. Both open the panel on the first
        // affected Account.
        let openAccount: @MainActor (Account.ID) -> Void = {
            [weak menuBarController] accountID in
            menuBarController?.showPanel(focusing: accountID)
        }
        let healthNotifications = HealthNotificationCoordinator(
            authorization: SystemNotificationAuthorizationProvider(),
            notificationDeliverer: SystemNotificationDeliverer(
                openAccount: openAccount
            ),
            toastPresenter: HealthToastWindowController(),
            openAccount: openAccount
        )
        healthNotificationCoordinator = healthNotifications
        monitor.healthNotificationSink = healthNotifications

        monitor.startPolling()
        Task { await monitor.refresh() }

        // A fresh live install has no Accounts, so onboarding replaces the
        // useful but empty panel. Mock mode already has fixture Accounts, so it
        // goes straight to the panel instead of asking for a credential.
        let presentation = LaunchPresentation.make(
            mode: dataSourceMode,
            storedAccountCount: accountManager.accounts.count
        )
        if presentation.showsOnboarding {
            showOnboarding()
        }
        if presentation.showsPanel {
            menuBarController.showPanel()
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
                makeConnectionTester: { [weak self] in
                    self?.makeConnectionTester()
                        ?? ProviderRegistryConnectionTester(adapters: [:])
                },
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
            return MockConnectionTester()
        case .live:
            guard let credentialStore, let transport else {
                // Only reachable before launch wiring completes; fail honestly
                // instead of fabricating a successful connection.
                return ProviderRegistryConnectionTester(adapters: [:])
            }
            return ProviderRegistryConnectionTester.live(
                credentialStore: credentialStore,
                transport: transport
            )
        }
    }

    /// Account CRUD changes the Account list, so the monitor re-reads its data
    /// source and refreshes rather than waiting for a relaunch.
    private func reloadMonitorAccounts() {
        guard let monitor, let store, let credentialStore, let transport else {
            return
        }
        let dataSource = BalanceDataSource.make(
            mode: dataSourceMode,
            store: store,
            credentialStore: credentialStore,
            transport: transport
        )
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
