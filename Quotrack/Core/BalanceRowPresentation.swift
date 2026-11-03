import Foundation

/// The visual emphasis of an Account row. Derived in the shared core so the
/// low-Balance threshold comparison and status precedence stay testable
/// without SwiftUI.
enum BalanceRowTone: Equatable, Sendable {
    case normal
    /// The Snapshot is fresh and its Health is warning.
    case warning
    /// The Snapshot is fresh and its Health is critical.
    case critical
    /// The Snapshot is fresh but the Account has no thresholds.
    case unset
    /// No successful refresh within three Polling Intervals; last known
    /// Balance stays visible but may be outdated.
    case stale
    /// The Provider reported the Account as unavailable.
    case unavailable
    /// The Account's Provider is no longer supported; the row is legacy-only.
    case unsupported
    /// The last refresh failed.
    case error
    /// No Snapshot and no failure yet.
    case pending
}

/// Display-ready state for one Account row. Deriving it in the shared core
/// keeps the panel a thin renderer and keeps formatting testable.
struct BalanceRowViewState: Identifiable, Equatable, Sendable {
    let id: Account.ID
    let providerName: String
    let label: String
    let balanceText: String
    let updatedText: String
    let statusText: String
    let status: SnapshotStatus?
    let tone: BalanceRowTone
    let health: AccountHealth
    let healthText: String
    let thresholdText: String
    /// False when the row has no evaluable Health (error, pending, unsupported,
    /// no snapshot, no thresholds, or a currency/kind mismatch). The threshold
    /// text and detail still explain why.
    let showsHealth: Bool
    let isQuota: Bool
    let quotaRemainingText: String?
    let quotaUsedText: String?
    let quotaResetText: String?
    let quotaSecondaryText: String?
    let quotaRemainingRatio: Double?
    let isExperimental: Bool
}

/// One breakdown line in an expanded row.
struct BalanceBreakdownViewState: Equatable, Sendable, Identifiable {
    let kind: BalanceBreakdownItem.Kind
    let label: String
    let amountText: String

    var id: BalanceBreakdownItem.Kind { kind }
}

/// Display-ready contents of one expanded Account row.
struct BalanceRowDetailViewState: Equatable, Sendable {
    let accountID: Account.ID
    /// The full-precision Balance; rows round to two decimals instead.
    let balanceText: String?
    /// Absolute fetch time, in contrast to the row's relative time.
    let fetchedAtText: String?
    /// Human-readable detail for the typed failure, if this row has one.
    let errorText: String?
    let breakdown: [BalanceBreakdownViewState]
    let healthText: String
    let thresholdText: String
    /// Expanded Quota detail: remaining/limit, used percentage, reset time,
    /// and secondary windows.
    let quotaLines: [String]
    /// Set when the Account's threshold currency no longer matches the
    /// Snapshot currency, so Health is not evaluated.
    let currencyWarningText: String?
}

enum BalanceRowPresentation {
    private static let placeholder = "—"
    private static let amountLocale = Locale(identifier: "en_US_POSIX")
    private static let relativeLocale = Locale(identifier: "zh_CN")

    static func viewState(for row: BalanceRow, now: Date) -> BalanceRowViewState {
        let status = row.isUnsupported ? SnapshotStatus.unsupported : row.status
        let health = health(for: row)
        let thresholds = row.account.thresholds
        let quota = row.quotaSnapshot
        let isQuota = row.account.kind == .subscription
        let showsHealth = !row.isUnsupported
            && row.error == nil
            && row.status != .error
            && row.status != nil
            && row.snapshot != nil
            && (thresholds.warning != nil || thresholds.critical != nil)
            && health != .unset
        return BalanceRowViewState(
            id: row.id,
            providerName: row.account.provider.displayName,
            label: row.account.label,
            balanceText: row.isUnsupported
                ? placeholder
                : row.balanceSnapshot.map(balanceText(for:)) ?? placeholder,
            updatedText: row.isUnsupported
                ? placeholder
                : row.snapshot.map { relativeText(for: $0.fetchedAt, now: now) } ?? placeholder,
            statusText: status.map(statusText(for:)) ?? placeholder,
            status: status,
            tone: tone(for: row),
            health: health,
            healthText: health.displayText,
            thresholdText: thresholdText(for: row),
            showsHealth: showsHealth,
            isQuota: isQuota,
            quotaRemainingText: quota.map {
                "剩余 \(decimalText($0.remaining)) / \(decimalText($0.limit))"
            },
            quotaUsedText: quota.map {
                "已用 \(percentText(usedPercent($0)))"
            },
            quotaResetText: quota?.resetAt.map {
                "额度重置 \(quotaDateText($0))"
            },
            quotaSecondaryText: quota?.windows.flatMap { windows in
                guard !windows.isEmpty else {
                    return nil
                }
                return windows.map { window in
                    let ratio = window.limit > 0
                        ? window.remaining / window.limit * 100
                        : 0
                    return "\(window.name)：剩余 \(percentText(ratio))"
                }.joined(separator: " · ")
            },
            quotaRemainingRatio: quota.map {
                let clamped = max(Decimal(0), min($0.remainingRatio, Decimal(1)))
                return NSDecimalNumber(decimal: clamped).doubleValue
            },
            isExperimental: row.account.provider == .moonshot
                && row.account.kind == .subscription
        )
    }

    /// Status wins over the low-Balance warning: an error is red and a Stale
    /// Snapshot is gray even when its last known Balance is below the
    /// threshold. Only a fresh Balance below the Account's threshold is amber.
    /// The warning applies at or below the threshold, matching AccountHealth.
    /// No Snapshot or no threshold means there is nothing to compare.
    static func tone(for row: BalanceRow) -> BalanceRowTone {
        // A legacy Provider is a permanent state, not a transient failure.
        if row.isUnsupported {
            return .unsupported
        }
        // A current failure outranks any freshness label, including a Stale
        // Snapshot, so an old Balance never hides an active error.
        if row.error != nil {
            return .error
        }
        guard let status = row.status else {
            return .pending
        }
        switch status {
        case .error:
            return .error
        case .stale:
            return .stale
        case .unavailable:
            return .unavailable
        case .unsupported:
            return .unsupported
        case .fresh:
            switch health(for: row) {
            case .normal: return .normal
            case .warning: return .warning
            case .critical: return .critical
            case .unset: return .unset
            }
        }
    }

    private static func health(for row: BalanceRow) -> AccountHealth {
        row.isUnsupported
            ? .unset
            : AccountHealthEvaluator.health(for: row.account, snapshot: row.snapshot)
    }

    private static func thresholdText(for row: BalanceRow) -> String {
        let thresholds = row.account.thresholds
        var parts: [String] = []
        if let warning = thresholds.warning {
            parts.append(
                "\(UIStrings.warningThresholdShort) \(thresholdValue(warning, for: row))"
            )
        }
        if let critical = thresholds.critical {
            parts.append(
                "\(UIStrings.criticalThresholdShort) \(thresholdValue(critical, for: row))"
            )
        }
        return parts.isEmpty ? UIStrings.thresholdUnset : parts.joined(separator: " · ")
    }

    private static func thresholdValue(_ value: Decimal, for row: BalanceRow) -> String {
        if row.account.kind == .subscription {
            return "\(value)%"
        }
        let symbol = row.account.currency?.symbol
            ?? row.balanceSnapshot?.balance.currency.symbol
            ?? ""
        return "\(symbol)\(value)"
    }

    private static func decimalText(_ value: Decimal) -> String {
        value.formatted(
            .number.precision(.fractionLength(0...2)).locale(amountLocale)
        )
    }

    private static func percentText(_ value: Decimal) -> String {
        value.formatted(
            .number.precision(.fractionLength(0...2)).locale(amountLocale)
        ) + "%"
    }

    private static func quotaDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    static func detailViewState(
        for row: BalanceRow,
        timeZone: TimeZone = .current
    ) -> BalanceRowDetailViewState {
        guard !row.isUnsupported else {
            return BalanceRowDetailViewState(
                accountID: row.id,
                balanceText: nil,
                fetchedAtText: nil,
                errorText: nil,
                breakdown: [],
                healthText: AccountHealth.unset.displayText,
                thresholdText: thresholdText(for: row),
                quotaLines: [],
                currencyWarningText: nil
            )
        }
        let snapshot = row.balanceSnapshot
        let health = health(for: row)
        return BalanceRowDetailViewState(
            accountID: row.id,
            balanceText: snapshot.map(preciseBalanceText(for:)),
            fetchedAtText: row.snapshot.map {
                exactTimeText(for: $0.fetchedAt, timeZone: timeZone)
            },
            errorText: row.error.map { $0.userMessage(for: row.account.provider) },
            breakdown: (snapshot?.breakdown ?? []).map { item in
                BalanceBreakdownViewState(
                    kind: item.kind,
                    label: breakdownLabel(for: item.kind),
                    amountText: (snapshot?.balance.currency.symbol ?? "") + item.amount.description
                )
            },
            healthText: health.displayText,
            thresholdText: thresholdText(for: row),
            quotaLines: quotaLines(for: row),
            currencyWarningText: currencyWarning(for: row)
        )
    }

    private static func quotaLines(for row: BalanceRow) -> [String] {
        guard let quota = row.quotaSnapshot else {
            return []
        }
        var lines = [
            "剩余 \(decimalText(quota.remaining)) / \(decimalText(quota.limit))",
            "已用 \(percentText(usedPercent(quota)))",
        ]
        if let resetAt = quota.resetAt {
            lines.append("额度重置 \(quotaDateText(resetAt))")
        }
        for window in quota.windows ?? [] {
            let ratio = window.limit > 0
                ? window.remaining / window.limit * 100
                : 0
            lines.append("\(window.name)：剩余 \(percentText(ratio))")
        }
        return lines
    }

    private static func usedPercent(_ quota: QuotaSnapshot) -> Decimal {
        let remaining = max(Decimal(0), min(quota.remainingRatio, Decimal(1)))
        return (Decimal(1) - remaining) * 100
    }

    private static func currencyWarning(for row: BalanceRow) -> String? {
        let thresholds = row.account.thresholds
        guard row.account.kind == .balance,
              thresholds.warning != nil || thresholds.critical != nil,
              let accountCurrency = row.account.currency,
              let snapshotCurrency = row.balanceSnapshot?.balance.currency,
              accountCurrency != snapshotCurrency else {
            return nil
        }
        return UIStrings.currencyMismatchWarning(
            thresholdCurrency: accountCurrency.code,
            balanceCurrency: snapshotCurrency.code
        )
    }

    private static func balanceText(for snapshot: BalanceSnapshot) -> String {
        let amount = snapshot.balance.amount.formatted(
            .number.precision(.fractionLength(2)).locale(amountLocale)
        )
        return snapshot.balance.currency.symbol + amount
    }

    /// No rounding: the expanded view shows every digit the Provider sent.
    private static func preciseBalanceText(for snapshot: BalanceSnapshot) -> String {
        snapshot.balance.currency.symbol + snapshot.balance.amount.description
    }

    private static func exactTimeText(for date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func relativeText(for fetchedAt: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = relativeLocale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: fetchedAt, relativeTo: now)
    }

    private static func breakdownLabel(for kind: BalanceBreakdownItem.Kind) -> String {
        switch kind {
        case .granted: UIStrings.breakdownGranted
        case .toppedUp: UIStrings.breakdownToppedUp
        case .voucher: UIStrings.breakdownVoucher
        case .cash: UIStrings.breakdownCash
        case .totalCredits: UIStrings.breakdownTotalCredits
        case .spend: UIStrings.breakdownSpend
        }
    }

    private static func statusText(for status: SnapshotStatus) -> String {
        switch status {
        case .fresh: UIStrings.statusFresh
        case .stale: "已过期"
        case .unavailable: "不可用"
        case .unsupported: UIStrings.unsupportedProviderState
        case .error: "错误"
        }
    }
}
