import Foundation

/// The visual emphasis of an Account row. Derived in the shared core so the
/// low-Balance threshold comparison and status precedence stay testable
/// without SwiftUI.
enum BalanceRowTone: Equatable, Sendable {
    case normal
    /// The Snapshot is fresh but its Balance is below the Account's threshold.
    case lowBalance
    /// No successful refresh within three Polling Intervals; last known
    /// Balance stays visible but may be outdated.
    case stale
    /// The Provider reported the Account as unavailable.
    case unavailable
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
}

enum BalanceRowPresentation {
    private static let placeholder = "—"
    private static let amountLocale = Locale(identifier: "en_US_POSIX")
    private static let relativeLocale = Locale(identifier: "zh_CN")

    static func viewState(for row: BalanceRow, now: Date) -> BalanceRowViewState {
        BalanceRowViewState(
            id: row.id,
            providerName: row.account.provider.displayName,
            label: row.account.label,
            balanceText: row.balanceSnapshot.map(balanceText(for:)) ?? placeholder,
            updatedText: row.snapshot.map { relativeText(for: $0.fetchedAt, now: now) } ?? placeholder,
            statusText: row.status.map(statusText(for:)) ?? placeholder,
            status: row.status,
            tone: tone(for: row)
        )
    }

    /// Status wins over the low-Balance warning: an error is red and a Stale
    /// Snapshot is gray even when its last known Balance is below the
    /// threshold. Only a fresh Balance below the Account's threshold is amber.
    /// The warning is strictly below, so a Balance equal to the threshold is
    /// still normal. No Snapshot or no threshold means there is nothing to
    /// compare.
    static func tone(for row: BalanceRow) -> BalanceRowTone {
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
        case .fresh:
            guard
                let threshold = row.account.lowBalanceThreshold,
                let amount = row.balanceSnapshot?.balance.amount,
                amount < threshold
            else {
                return .normal
            }
            return .lowBalance
        }
    }

    static func detailViewState(
        for row: BalanceRow,
        timeZone: TimeZone = .current
    ) -> BalanceRowDetailViewState {
        let snapshot = row.balanceSnapshot
        return BalanceRowDetailViewState(
            accountID: row.id,
            balanceText: snapshot.map(preciseBalanceText(for:)),
            fetchedAtText: snapshot.map { exactTimeText(for: $0.fetchedAt, timeZone: timeZone) },
            errorText: row.error.map { $0.userMessage(for: row.account.provider) },
            breakdown: (snapshot?.breakdown ?? []).map { item in
                BalanceBreakdownViewState(
                    kind: item.kind,
                    label: breakdownLabel(for: item.kind),
                    amountText: (snapshot?.balance.currency.symbol ?? "") + item.amount.description
                )
            }
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
        case .fresh: "正常"
        case .stale: "已过期"
        case .unavailable: "不可用"
        case .error: "错误"
        }
    }
}
