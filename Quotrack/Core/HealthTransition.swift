import Foundation

/// One observed change in an Account's Health between two completed polls.
/// Transitions only ever join normal, warning, and critical; unset, Stale, and
/// error are not Health transitions.
struct HealthTransition: Equatable, Sendable, Identifiable {
    let accountID: Account.ID
    let provider: Provider
    let label: String
    let kind: AccountKind
    let from: AccountHealth
    let to: AccountHealth

    var id: Account.ID { accountID }
}

/// Every transition detected after one poll. A batch is delivered as at most
/// one notification, no matter how many Accounts changed.
struct HealthNotificationBatch: Equatable, Sendable {
    let transitions: [HealthTransition]

    var isEmpty: Bool { transitions.isEmpty }

    /// The Account a click on the aggregated notification reveals. Rows are
    /// processed in panel order, so this is the first affected row.
    var firstAffectedAccountID: Account.ID? {
        transitions.first?.accountID
    }
}

/// Sticky Health used for notifications. The panel keeps showing the raw
/// threshold-derived Health; only the transition decision is hysteretic.
enum HealthHysteresis {
    /// 5% of the threshold amount for Balance, 5 remaining percentage points
    /// for Quota. Quota thresholds are already percentages.
    static func band(for kind: AccountKind, threshold: Decimal) -> Decimal {
        switch kind {
        case .balance:
            threshold * Decimal(string: "0.05")!
        case .subscription:
            5
        }
    }

    /// The next remembered Health for an Account. Entering a worse state uses
    /// the raw threshold; returning to the previous level requires crossing
    /// the band on the better side. A nil threshold can never be entered.
    static func nextHealth(
        previous: AccountHealth,
        value: Decimal,
        thresholds: AccountThresholds,
        kind: AccountKind
    ) -> AccountHealth {
        guard (try? thresholds.validate(for: kind)) != nil else {
            return .unset
        }
        let warning = thresholds.warning
        let critical = thresholds.critical

        switch previous {
        case .unset:
            return AccountHealthEvaluator.health(
                value: value,
                thresholds: thresholds,
                kind: kind
            )
        case .normal:
            if let critical, value <= critical {
                return .critical
            }
            if let warning, value <= warning {
                return .warning
            }
            return .normal
        case .warning:
            if let critical, value <= critical {
                return .critical
            }
            guard let warning else {
                // The warning threshold was cleared while the Account was
                // remembered as warning. Fall back to the current rule.
                return AccountHealthEvaluator.health(
                    value: value,
                    thresholds: thresholds,
                    kind: kind
                )
            }
            if value > warning + band(for: kind, threshold: warning) {
                return .normal
            }
            return .warning
        case .critical:
            guard let critical else {
                // The critical threshold was cleared; use the current rule.
                return AccountHealthEvaluator.health(
                    value: value,
                    thresholds: thresholds,
                    kind: kind
                )
            }
            if value <= critical + band(for: kind, threshold: critical) {
                return .critical
            }
            if let warning,
               value <= warning + band(for: kind, threshold: warning) {
                return .warning
            }
            return .normal
        }
    }
}

/// Pure, stateful transition detection. Feed it the monitor rows after every
/// completed refresh; the first observation of an Account establishes its
/// baseline silently. Stale, unavailable, unsupported, and errored rows neither
/// notify nor change the remembered state; a row whose Health becomes unset
/// clears its baseline so re-adding thresholds starts fresh.
struct HealthTransitionDetector: Sendable {
    private var remembered: [Account.ID: AccountHealth] = [:]

    /// Returns at most one batch for the whole poll. Each Account appears at
    /// most once, and only when its remembered Health actually changed.
    mutating func observe(rows: [BalanceRow]) -> HealthNotificationBatch {
        var transitions: [HealthTransition] = []

        for row in rows {
            guard !row.isUnsupported,
                  row.error == nil,
                  row.status == .fresh,
                  let snapshot = row.snapshot else {
                // Stale, error, unavailable, unsupported, and not-yet-fetched
                // rows are not Health transitions. Keep the last remembered
                // Health so a later successful poll can report the change.
                continue
            }

            guard let value = AccountHealthEvaluator.metricValue(
                for: row.account,
                snapshot: snapshot
            ) else {
                // Unset is not a transition. Clear the baseline so adding
                // thresholds later starts from a fresh observation.
                remembered[row.account.id] = nil
                continue
            }
            let thresholds = row.account.thresholds
            let raw = AccountHealthEvaluator.health(
                value: value,
                thresholds: thresholds,
                kind: row.account.kind
            )
            guard raw != .unset else {
                remembered[row.account.id] = nil
                continue
            }

            let previous = remembered[row.account.id]
            let next: AccountHealth
            if let previous, previous != .unset {
                next = HealthHysteresis.nextHealth(
                    previous: previous,
                    value: value,
                    thresholds: thresholds,
                    kind: row.account.kind
                )
            } else {
                next = raw
            }
            remembered[row.account.id] = next

            guard let previous, previous != .unset, previous != next else {
                continue
            }
            transitions.append(
                HealthTransition(
                    accountID: row.account.id,
                    provider: row.account.provider,
                    label: row.account.label,
                    kind: row.account.kind,
                    from: previous,
                    to: next
                )
            )
        }

        return HealthNotificationBatch(transitions: transitions)
    }
}
