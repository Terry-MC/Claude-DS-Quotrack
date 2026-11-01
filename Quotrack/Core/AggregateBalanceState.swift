import Foundation

/// Aggregate health of all Accounts, shown by the menu bar icon. Derived from
/// the same row appearances as the panel so the icon and the rows never
/// disagree.
enum AggregateBalanceState: Int, Comparable, Sendable {
    /// Every Snapshot is fresh and at or above its Account's threshold.
    case normal = 0
    /// At least one Snapshot is Stale, unavailable, or below its threshold.
    case warning = 1
    /// At least one Account is in error. Errors outrank warnings.
    case error = 2

    static func < (lhs: AggregateBalanceState, rhs: AggregateBalanceState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Error wins over warning regardless of row order; a row that has not
    /// loaded yet contributes normal.
    static func derive(from rows: [BalanceRow]) -> AggregateBalanceState {
        rows.map { BalanceRowPresentation.tone(for: $0).appearance.aggregateState }
            .max() ?? .normal
    }
}
