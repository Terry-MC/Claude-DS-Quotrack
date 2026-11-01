import Foundation

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
            balanceText: row.snapshot.map(balanceText(for:)) ?? placeholder,
            updatedText: row.snapshot.map { relativeText(for: $0.fetchedAt, now: now) } ?? placeholder,
            statusText: row.status.map(statusText(for:)) ?? placeholder,
            status: row.status
        )
    }

    private static func balanceText(for snapshot: BalanceSnapshot) -> String {
        let amount = snapshot.balance.amount.formatted(
            .number.precision(.fractionLength(2)).locale(amountLocale)
        )
        return snapshot.balance.currency.symbol + amount
    }

    private static func relativeText(for fetchedAt: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = relativeLocale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: fetchedAt, relativeTo: now)
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
