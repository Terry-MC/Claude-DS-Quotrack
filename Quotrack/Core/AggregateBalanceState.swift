import Foundation

/// Aggregate health of all Accounts, shown by the menu bar icon. Derived from
/// the same row appearances as the panel so the icon and the rows never
/// disagree.
enum AggregateBalanceState: Int, Comparable, Sendable {
    /// Every Snapshot is fresh and at or above its Account's threshold.
    case normal = 0
    /// At least one Snapshot is Stale, unavailable, or at its warning line.
    case warning = 1
    /// At least one Account is at its critical line.
    case critical = 2
    /// At least one Account is in error. Errors outrank warnings and critical.
    case error = 3

    static func < (lhs: AggregateBalanceState, rhs: AggregateBalanceState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Error wins over critical, critical over warning, and warning over
    /// normal. Health is considered even when the Snapshot is Stale, so a
    /// stale critical Account does not silently downgrade the menu bar.
    static func derive(from rows: [BalanceRow]) -> AggregateBalanceState {
        let toneState = rows
            .map { BalanceRowPresentation.tone(for: $0).appearance.aggregateState }
            .max() ?? .normal
        let healthState = rows.map { row -> AggregateBalanceState in
            guard !row.isUnsupported else {
                return .normal
            }
            return AccountHealthEvaluator
                .health(for: row.account, snapshot: row.snapshot)
                .aggregateState
        }.max() ?? .normal
        return max(toneState, healthState)
    }
}

extension AccountHealth {
    /// The menu-bar severity contributed by this Health. Stale and error are
    /// separate and are handled by the row tone.
    var aggregateState: AggregateBalanceState {
        switch self {
        case .critical: .critical
        case .warning: .warning
        case .normal, .unset: .normal
        }
    }
}
