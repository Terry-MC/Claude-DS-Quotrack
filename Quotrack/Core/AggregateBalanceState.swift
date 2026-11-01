import Foundation

/// Aggregate health of all Accounts, shown by the menu bar icon. Derived from
/// the same row tones as the panel so the icon and the rows never disagree.
enum AggregateBalanceState: Equatable, Sendable {
    /// Every Snapshot is fresh and at or above its Account's threshold.
    case normal
    /// At least one Snapshot is Stale, unavailable, or below its threshold.
    case warning
    /// At least one Account is in error. Errors outrank warnings.
    case error

    /// Error wins over warning regardless of row order; a row that has not
    /// loaded yet contributes nothing.
    static func derive(from rows: [BalanceRow]) -> AggregateBalanceState {
        var hasWarning = false
        for row in rows {
            switch BalanceRowPresentation.tone(for: row) {
            case .error:
                return .error
            case .lowBalance, .stale, .unavailable:
                hasWarning = true
            case .normal, .pending:
                break
            }
        }
        return hasWarning ? .warning : .normal
    }
}
