import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var monitor: LiveBalanceMonitor?
    private var dataSourceMode = DataSourceMode.live

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        dataSourceMode = LaunchOptions
            .parse(arguments: ProcessInfo.processInfo.arguments)
            .dataSourceMode
        let monitor = LiveBalanceMonitor(
            dataSource: BalanceDataSource.make(mode: dataSourceMode)
        )
        self.monitor = monitor

        let menuBarController = MenuBarController(monitor: monitor)
        menuBarController.onSwitchDataSource = { [weak self] in
            self?.toggleDataSource()
        }
        self.menuBarController = menuBarController

        monitor.startPolling()
        Task { await monitor.refresh() }
    }

    private func toggleDataSource() {
        dataSourceMode = dataSourceMode.toggled
        guard let monitor else {
            return
        }
        let dataSource = BalanceDataSource.make(mode: dataSourceMode)
        Task { await monitor.switchDataSource(dataSource) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
