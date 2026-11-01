import Foundation

enum MenuBarClick: Sendable, Equatable {
    case left
    case right
}

@MainActor
protocol PanelPresenting: AnyObject {
    var isVisible: Bool { get }
    func show()
    func hide()
}

@MainActor
protocol MenuPresenting: AnyObject {
    func showMenu()
}

@MainActor
final class MenuBarInteractionHandler {
    private let panel: any PanelPresenting
    private let menu: any MenuPresenting

    init(panel: any PanelPresenting, menu: any MenuPresenting) {
        self.panel = panel
        self.menu = menu
    }

    func handle(_ click: MenuBarClick) {
        switch click {
        case .left:
            if panel.isVisible {
                panel.hide()
            } else {
                panel.show()
            }
        case .right:
            menu.showMenu()
        }
    }
}
