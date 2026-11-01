import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var monitor: LiveBalanceMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // The mock slice renders one Account without credentials or network.
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let monitor = LiveBalanceMonitor(provider: MockBalanceProvider(), accounts: [account])
        self.monitor = monitor
        menuBarController = MenuBarController(monitor: monitor)

        Task { await monitor.refresh() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
