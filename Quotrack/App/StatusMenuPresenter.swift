import AppKit

@MainActor
final class StatusMenuPresenter: MenuPresenting {
    private let menu: NSMenu
    weak var statusItem: NSStatusItem?

    init(menu: NSMenu) {
        self.menu = menu
    }

    func showMenu() {
        guard let statusItem, let button = statusItem.button else {
            return
        }
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }
}
