import Testing

@MainActor
struct MenuBarInteractionTests {
    @Test
    func leftClickOnHiddenPanelShowsIt() {
        let panel = FakePanel()
        let menu = FakeMenu()
        let sut = MenuBarInteractionHandler(panel: panel, menu: menu)

        sut.handle(.left)

        #expect(panel.isVisible)
    }

    @Test
    func leftClickOnVisiblePanelHidesIt() {
        let panel = FakePanel()
        let menu = FakeMenu()
        let sut = MenuBarInteractionHandler(panel: panel, menu: menu)
        panel.show()

        sut.handle(.left)

        #expect(!panel.isVisible)
    }

    @Test
    func rightClickShowsMenuWithoutChangingPanelVisibility() {
        let panel = FakePanel()
        let menu = FakeMenu()
        let sut = MenuBarInteractionHandler(panel: panel, menu: menu)
        panel.show()

        sut.handle(.right)

        #expect(menu.showCount == 1)
        #expect(panel.isVisible)
    }
}

@MainActor
private final class FakePanel: PanelPresenting {
    private(set) var isVisible = false

    func show() {
        isVisible = true
    }

    func hide() {
        isVisible = false
    }
}

@MainActor
private final class FakeMenu: MenuPresenting {
    private(set) var showCount = 0

    func showMenu() {
        showCount += 1
    }
}
