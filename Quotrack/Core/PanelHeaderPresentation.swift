/// Display-ready summary of the panel's Account states.
struct PanelHeaderViewState: Equatable, Sendable {
    let healthyCount: Int
    let warningCount: Int
    let criticalCount: Int
    let errorCount: Int

    var title: String { UIStrings.displayName }
    var subtitle: String { UIStrings.displaySubtitle }
    var healthyText: String { "正常 \(healthyCount)" }
    var warningText: String { "预警 \(warningCount)" }
    var criticalText: String { "紧急 \(criticalCount)" }
    var errorText: String { "错误 \(errorCount)" }
}

enum PanelHeaderPresentation {
    static func viewState(for rows: [BalanceRow]) -> PanelHeaderViewState {
        var healthyCount = 0
        var warningCount = 0
        var criticalCount = 0
        var errorCount = 0

        for row in rows {
            if row.error != nil || row.status == .error {
                errorCount += 1
                continue
            }
            if row.isUnsupported {
                continue
            }

            let health = AccountHealthEvaluator.health(
                for: row.account,
                snapshot: row.snapshot
            )
            switch health {
            case .critical:
                criticalCount += 1
            case .warning:
                warningCount += 1
            case .normal:
                if row.status == .stale || row.status == .unavailable {
                    warningCount += 1
                } else {
                    healthyCount += 1
                }
            case .unset:
                if row.status == .stale || row.status == .unavailable {
                    warningCount += 1
                }
            }
        }

        return PanelHeaderViewState(
            healthyCount: healthyCount,
            warningCount: warningCount,
            criticalCount: criticalCount,
            errorCount: errorCount
        )
    }
}
