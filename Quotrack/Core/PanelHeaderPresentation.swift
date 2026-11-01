/// Display-ready summary of the panel's Account states.
struct PanelHeaderViewState: Equatable, Sendable {
    let healthyCount: Int
    let errorCount: Int

    var title: String { UIStrings.displayName }
    var subtitle: String { UIStrings.displaySubtitle }
    var healthyText: String { "正常 \(healthyCount)" }
    var errorText: String { "错误 \(errorCount)" }
}

enum PanelHeaderPresentation {
    static func viewState(for rows: [BalanceRow]) -> PanelHeaderViewState {
        PanelHeaderViewState(
            healthyCount: rows.filter { $0.status == .fresh }.count,
            errorCount: rows.filter { $0.status == .error }.count
        )
    }
}
