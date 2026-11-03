import Foundation

/// The dock's severity. It is derived from Account Health only: Stale and
/// error are separate states handled by the panel and menu bar, while the dock
/// answers "how many Accounts are warning or critical?".
enum DockStatus: Int, Comparable, Sendable, Equatable {
    case normal = 0
    case warning = 1
    case critical = 2

    static func < (lhs: DockStatus, rhs: DockStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Pure view state for the docked side panel. AppKit and SwiftUI only render
/// this value, so badge counts, severity, and the Reduce Motion decision are
/// testable without a window.
struct DockPresentation: Equatable, Sendable {
    let status: DockStatus
    /// The number of Accounts in warning or critical, matching the spec's dock
    /// badge definition. Normal and unset Accounts are not counted.
    let badgeCount: Int
    /// The badge label, or nil when there is nothing to show. Counts above
    /// ninety-nine are abbreviated so the dock stays narrow.
    let badgeText: String?
    /// A critical dock pulses unless Reduce Motion is on.
    let isPulsing: Bool

    var accessibilityDescription: String {
        switch status {
        case .normal:
            UIStrings.dockNormalDescription
        case .warning:
            UIStrings.dockWarningDescription(count: badgeCount)
        case .critical:
            UIStrings.dockCriticalDescription(count: badgeCount)
        }
    }

    static func make(
        healths: [AccountHealth],
        reduceMotion: Bool
    ) -> DockPresentation {
        let warningCount = healths.filter { $0 == .warning }.count
        let criticalCount = healths.filter { $0 == .critical }.count
        let badgeCount = warningCount + criticalCount
        let status: DockStatus
        if criticalCount > 0 {
            status = .critical
        } else if warningCount > 0 {
            status = .warning
        } else {
            status = .normal
        }
        return DockPresentation(
            status: status,
            badgeCount: badgeCount,
            badgeText: badgeText(for: badgeCount),
            isPulsing: status == .critical && !reduceMotion
        )
    }

    /// Derives Health from the same rows the panel and menu bar read. A legacy
    /// Account whose Provider is unsupported is never polled, so it must not
    /// add to the badge even if its old Snapshot is below a threshold.
    static func make(
        rows: [BalanceRow],
        reduceMotion: Bool
    ) -> DockPresentation {
        make(
            healths: rows.map { row in
                row.isUnsupported
                    ? .unset
                    : AccountHealthEvaluator.health(
                        for: row.account,
                        snapshot: row.snapshot
                    )
            },
            reduceMotion: reduceMotion
        )
    }

    private static func badgeText(for count: Int) -> String? {
        switch count {
        case 0:
            nil
        case 1...99:
            "\(count)"
        default:
            "99+"
        }
    }
}
