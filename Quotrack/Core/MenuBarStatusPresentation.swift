/// Display-ready menu bar icon for the aggregate Account state.
struct MenuBarStatusViewState: Equatable, Sendable {
    let symbolName: String
    let accessibilityDescription: String
}

enum MenuBarStatusPresentation {
    /// The icon changes with the aggregate state so the menu bar shows a
    /// low Balance, Stale data, or an error without opening the panel.
    static func viewState(for state: AggregateBalanceState) -> MenuBarStatusViewState {
        switch state {
        case .normal:
            MenuBarStatusViewState(
                symbolName: "dollarsign.circle.fill",
                accessibilityDescription: UIStrings.menuBarNormalDescription
            )
        case .warning:
            MenuBarStatusViewState(
                symbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: UIStrings.menuBarWarningDescription
            )
        case .critical:
            MenuBarStatusViewState(
                symbolName: "exclamationmark.circle.fill",
                accessibilityDescription: UIStrings.menuBarCriticalDescription
            )
        case .error:
            MenuBarStatusViewState(
                symbolName: "exclamationmark.octagon.fill",
                accessibilityDescription: UIStrings.menuBarErrorDescription
            )
        }
    }
}
