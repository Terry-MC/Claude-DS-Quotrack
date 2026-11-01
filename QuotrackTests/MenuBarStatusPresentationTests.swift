import Testing

struct MenuBarStatusPresentationTests {
    @Test
    func normalStateShowsTheNormalIconAndDescription() {
        let viewState = MenuBarStatusPresentation.viewState(for: .normal)

        #expect(viewState.symbolName == "dollarsign.circle.fill")
        #expect(viewState.accessibilityDescription == UIStrings.menuBarNormalDescription)
    }

    @Test
    func warningStateShowsAWarningIconAndDescription() {
        let viewState = MenuBarStatusPresentation.viewState(for: .warning)

        #expect(viewState.symbolName == "exclamationmark.triangle.fill")
        #expect(viewState.accessibilityDescription == UIStrings.menuBarWarningDescription)
    }

    @Test
    func errorStateShowsAnErrorIconAndDescription() {
        let viewState = MenuBarStatusPresentation.viewState(for: .error)

        #expect(viewState.symbolName == "exclamationmark.octagon.fill")
        #expect(viewState.accessibilityDescription == UIStrings.menuBarErrorDescription)
    }

    @Test
    func everyAggregateStateHasADistinctIconAndDescription() {
        let viewStates = [
            MenuBarStatusPresentation.viewState(for: .normal),
            MenuBarStatusPresentation.viewState(for: .warning),
            MenuBarStatusPresentation.viewState(for: .error),
        ]

        #expect(Set(viewStates.map(\.symbolName)).count == viewStates.count)
        #expect(Set(viewStates.map(\.accessibilityDescription)).count == viewStates.count)
    }
}
