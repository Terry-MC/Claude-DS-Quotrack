import Foundation

/// The state derived from an Account's latest successful Snapshot and its
/// Thresholds. Stale and error are separate states and never become Health.
enum AccountHealth: Int, Comparable, Sendable {
    case unset = 0
    case normal = 1
    case warning = 2
    case critical = 3

    static func < (lhs: AccountHealth, rhs: AccountHealth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Pure Health evaluation. The monitor and UI supply the latest successful
/// Snapshot; freshness and fetch errors remain outside this type.
enum AccountHealthEvaluator {
    static func health(for account: Account, snapshot: AccountSnapshot?) -> AccountHealth {
        guard let snapshot else {
            return .unset
        }
        let thresholds = account.thresholds
        do {
            try thresholds.validate(for: account.kind)
        } catch {
            return .unset
        }
        switch account.kind {
        case .balance:
            guard let balanceSnapshot = snapshot.balanceSnapshot,
                  balanceSnapshot.isAvailable else {
                return .unset
            }
            if let currency = account.currency,
               currency != balanceSnapshot.balance.currency {
                return .unset
            }
            return evaluate(value: balanceSnapshot.balance.amount, thresholds: thresholds)
        case .subscription:
            guard let quota = snapshot.quotaSnapshot, quota.limit > 0 else {
                return .unset
            }
            return evaluate(value: quota.remainingPercent, thresholds: thresholds)
        }
    }

    /// Provider Health is the worst Account Health. An unset Account does not
    /// raise the Provider's severity.
    static func worst(_ healths: [AccountHealth]) -> AccountHealth {
        healths.max() ?? .unset
    }

    private static func evaluate(
        value: Decimal,
        thresholds: AccountThresholds
    ) -> AccountHealth {
        guard thresholds.warning != nil || thresholds.critical != nil else {
            return .unset
        }
        if let critical = thresholds.critical, value <= critical {
            return .critical
        }
        if let warning = thresholds.warning, value <= warning {
            return .warning
        }
        return .normal
    }
}

extension Account {
    /// The two thresholds as one value, so Health evaluation and the forms do
    /// not repeat the field pair.
    var thresholds: AccountThresholds {
        AccountThresholds(warning: warningThreshold, critical: criticalThreshold)
    }
}
