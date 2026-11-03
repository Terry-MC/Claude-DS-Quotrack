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

    var displayText: String {
        switch self {
        case .unset: UIStrings.healthUnset
        case .normal: UIStrings.healthNormal
        case .warning: UIStrings.healthWarning
        case .critical: UIStrings.healthCritical
        }
    }
}

/// Pure Health evaluation. The monitor and UI supply the latest successful
/// Snapshot; freshness and fetch errors remain outside this type.
enum AccountHealthEvaluator {
    static func health(for account: Account, snapshot: AccountSnapshot?) -> AccountHealth {
        guard let snapshot,
              let value = metricValue(for: account, snapshot: snapshot) else {
            return .unset
        }
        return health(value: value, thresholds: account.thresholds, kind: account.kind)
    }

    /// The numeric value Health compares against Thresholds. It is nil when the
    /// Snapshot cannot produce one: wrong Metric kind, unavailable Balance,
    /// currency mismatch, zero Quota limit, no thresholds, or an invalid pair.
    /// The notification detector uses the same value so display and alerts
    /// cannot disagree about what an Account is measuring.
    static func metricValue(
        for account: Account,
        snapshot: AccountSnapshot
    ) -> Decimal? {
        let thresholds = account.thresholds
        guard (try? thresholds.validate(for: account.kind)) != nil,
              thresholds.warning != nil || thresholds.critical != nil else {
            return nil
        }
        switch account.kind {
        case .balance:
            guard let balanceSnapshot = snapshot.balanceSnapshot,
                  balanceSnapshot.isAvailable else {
                return nil
            }
            if let currency = account.currency,
               currency != balanceSnapshot.balance.currency {
                return nil
            }
            return balanceSnapshot.balance.amount
        case .subscription:
            guard let quota = snapshot.quotaSnapshot, quota.limit > 0 else {
                return nil
            }
            return quota.remainingPercent
        }
    }

    /// Applies the raw thresholds: at or below the critical line is critical,
    /// at or below the warning line is warning, otherwise normal. Hysteresis is
    /// layered on top by `HealthHysteresis`, not here: the panel and menu bar
    /// keep showing the threshold-derived Health.
    static func health(
        value: Decimal,
        thresholds: AccountThresholds,
        kind: AccountKind
    ) -> AccountHealth {
        guard (try? thresholds.validate(for: kind)) != nil,
              thresholds.warning != nil || thresholds.critical != nil else {
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

    /// Provider Health is the worst Account Health. An unset Account does not
    /// raise the Provider's severity.
    static func worst(_ healths: [AccountHealth]) -> AccountHealth {
        healths.max() ?? .unset
    }
}

extension Account {
    /// The two thresholds as one value, so Health evaluation and the forms do
    /// not repeat the field pair.
    var thresholds: AccountThresholds {
        AccountThresholds(warning: warningThreshold, critical: criticalThreshold)
    }
}
