import Foundation

/// The one tone-to-appearance mapping. The panel's status dot, status label,
/// Balance color, and the menu bar aggregate all read this table, so a row
/// cannot render one severity while the menu bar reports another. The app
/// translates the emphasis roles into SwiftUI colors in one place.
struct BalanceRowAppearance: Equatable, Sendable {
    /// Semantic emphasis, independent of SwiftUI so the mapping stays testable
    /// in the shared core.
    enum Emphasis: Equatable, Sendable {
        case primary
        case positive
        case warning
        case muted
        case secondary
        case error
        case pending
    }

    let status: Emphasis
    let balance: Emphasis
    let aggregateState: AggregateBalanceState
}

extension BalanceRowTone {
    var appearance: BalanceRowAppearance {
        switch self {
        case .normal:
            BalanceRowAppearance(
                status: .positive,
                balance: .primary,
                aggregateState: .normal
            )
        case .lowBalance:
            BalanceRowAppearance(
                status: .warning,
                balance: .warning,
                aggregateState: .warning
            )
        case .stale:
            BalanceRowAppearance(
                status: .muted,
                balance: .secondary,
                aggregateState: .warning
            )
        case .unavailable:
            BalanceRowAppearance(
                status: .warning,
                balance: .warning,
                aggregateState: .warning
            )
        case .unsupported:
            BalanceRowAppearance(
                status: .muted,
                balance: .muted,
                aggregateState: .normal
            )
        case .error:
            BalanceRowAppearance(
                status: .error,
                balance: .error,
                aggregateState: .error
            )
        case .pending:
            BalanceRowAppearance(
                status: .pending,
                balance: .primary,
                aggregateState: .normal
            )
        }
    }
}
