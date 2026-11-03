import Foundation

/// One currency's Balance total inside a Provider summary. Amounts are never
/// converted, so each currency stays its own line.
struct ProviderBalanceTotalViewState: Identifiable, Equatable, Sendable {
    let currency: Currency
    let amount: Decimal
    let amountText: String

    var id: String { currency.code }
}

/// One Account Kind inside a Provider card. The section keeps the rows in
/// creation order and carries the collapsed summary for that Kind.
struct ProviderKindSectionViewState: Identifiable, Equatable, Sendable {
    let kind: AccountKind
    let title: String
    let rows: [BalanceRow]
    let accountCount: Int
    let health: AccountHealth
    let healthText: String
    let warningCount: Int
    let criticalCount: Int
    /// A failed fetch. Shown beside Health, never folded into it.
    let errorCount: Int
    /// A Snapshot older than three Polling Intervals. Shown beside Health,
    /// never folded into it.
    let staleCount: Int
    /// Balance only. One entry per currency, in first-appearance order.
    let balanceTotals: [ProviderBalanceTotalViewState]
    /// Quota only. The lowest remaining percentage across the section.
    let quotaWorstRemainingPercent: Decimal?
    let quotaWorstRemainingText: String?

    var id: AccountKind { kind }

    /// A single line such as "合计 ¥30.00 · $5.00". The label appears once
    /// because every amount on the line is a per-currency total.
    var balanceTotalText: String? {
        guard !balanceTotals.isEmpty else {
            return nil
        }
        return UIStrings.providerBalanceTotalLabel
            + " "
            + balanceTotals.map(\.amountText).joined(separator: " · ")
    }

    var quotaWorstRemainingSummaryText: String? {
        quotaWorstRemainingText.map(UIStrings.providerQuotaWorstRemaining)
    }
}

/// One Provider card: Provider identity, Provider Health, the per-Kind
/// sections, and the counts that stay separate from Health.
struct ProviderGroupViewState: Identifiable, Equatable, Sendable {
    let provider: Provider
    let name: String
    let sections: [ProviderKindSectionViewState]
    let health: AccountHealth
    let healthText: String
    let isCollapsed: Bool
    let accountCount: Int
    let warningCount: Int
    let criticalCount: Int
    let errorCount: Int
    let staleCount: Int

    var id: Provider { provider }

    /// For example "充值 2 · 订阅 1". The counts describe the Accounts the
    /// Provider card actually holds, not every Kind the Provider supports.
    var kindCountText: String {
        sections
            .map { UIStrings.providerKindCount($0.kind, $0.accountCount) }
            .joined(separator: " · ")
    }

    var errorText: String { UIStrings.providerErrorCount(errorCount) }
    var staleText: String { UIStrings.providerStaleCount(staleCount) }
}

/// Builds the panel's Provider cards and their per-Kind summaries without
/// touching SwiftUI. Providers stay in first-appearance (creation) order, and
/// Accounts keep their row order inside each section.
enum ProviderGroupPresentation {
    private static let amountLocale = Locale(identifier: "en_US_POSIX")

    static func groups(
        from rows: [BalanceRow],
        collapseState: ProviderCollapseState = ProviderCollapseState()
    ) -> [ProviderGroupViewState] {
        orderedProviders(from: rows).map { provider in
            let providerRows = rows.filter { $0.account.provider == provider }
            let healths = providerRows.map { health(for: $0) }
            let health = AccountHealthEvaluator.worst(healths)
            let sections: [ProviderKindSectionViewState] = AccountKind.allCases.compactMap { kind in
                let kindRows = providerRows.filter { $0.account.kind == kind }
                guard !kindRows.isEmpty else {
                    return nil
                }
                return section(kind: kind, rows: kindRows)
            }
            return ProviderGroupViewState(
                provider: provider,
                name: provider.displayName,
                sections: sections,
                health: health,
                healthText: health.displayText,
                isCollapsed: collapseState.isCollapsed(provider),
                accountCount: providerRows.count,
                warningCount: healths.filter { $0 == .warning }.count,
                criticalCount: healths.filter { $0 == .critical }.count,
                errorCount: providerRows.filter(isError).count,
                staleCount: providerRows.filter { $0.status == .stale }.count
            )
        }
    }

    private static func section(
        kind: AccountKind,
        rows: [BalanceRow]
    ) -> ProviderKindSectionViewState {
        let healths = rows.map { health(for: $0) }
        let health = AccountHealthEvaluator.worst(healths)
        let worstQuota = kind == .subscription
            ? quotaWorstRemaining(for: rows)
            : nil
        return ProviderKindSectionViewState(
            kind: kind,
            title: title(for: kind),
            rows: rows,
            accountCount: rows.count,
            health: health,
            healthText: health.displayText,
            warningCount: healths.filter { $0 == .warning }.count,
            criticalCount: healths.filter { $0 == .critical }.count,
            errorCount: rows.filter(isError).count,
            staleCount: rows.filter { $0.status == .stale }.count,
            balanceTotals: kind == .balance ? balanceTotals(for: rows) : [],
            quotaWorstRemainingPercent: worstQuota,
            quotaWorstRemainingText: worstQuota.map(percentText)
        )
    }

    /// A provider appears where its first Account appears. The monitor keeps
    /// Accounts in creation order, so this is creation order too.
    private static func orderedProviders(from rows: [BalanceRow]) -> [Provider] {
        var seen: Set<Provider> = []
        var ordered: [Provider] = []
        for row in rows {
            let provider = row.account.provider
            guard seen.insert(provider).inserted else {
                continue
            }
            ordered.append(provider)
        }
        return ordered
    }

    /// A legacy Account is never polled, so its persisted Snapshot must not
    /// make the Provider look healthy or contribute a Balance.
    private static func health(for row: BalanceRow) -> AccountHealth {
        row.isUnsupported
            ? .unset
            : AccountHealthEvaluator.health(for: row.account, snapshot: row.snapshot)
    }

    private static func isError(_ row: BalanceRow) -> Bool {
        row.error != nil || row.status == .error
    }

    /// Sums each currency separately, in first-appearance order. Stale and
    /// error rows keep their last known Balance, exactly as the row does.
    private static func balanceTotals(
        for rows: [BalanceRow]
    ) -> [ProviderBalanceTotalViewState] {
        var currencyOrder: [String] = []
        var totals: [String: (currency: Currency, amount: Decimal)] = [:]
        for row in rows where !row.isUnsupported {
            guard row.account.kind == .balance,
                  let balance = row.balanceSnapshot?.balance else {
                continue
            }
            let code = balance.currency.code
            if totals[code] == nil {
                currencyOrder.append(code)
                totals[code] = (balance.currency, 0)
            }
            totals[code]?.amount += balance.amount
        }
        return currencyOrder.compactMap { code in
            guard let total = totals[code] else {
                return nil
            }
            return ProviderBalanceTotalViewState(
                currency: total.currency,
                amount: total.amount,
                amountText: total.currency.symbol + total.amount.formatted(
                    .number.precision(.fractionLength(2)).locale(amountLocale)
                )
            )
        }
    }

    /// The worst remaining percentage ignores Accounts without a Quota
    /// Snapshot. A zero limit is malformed and contributes no percentage.
    private static func quotaWorstRemaining(for rows: [BalanceRow]) -> Decimal? {
        rows.compactMap { row -> Decimal? in
            guard !row.isUnsupported,
                  let quota = row.quotaSnapshot,
                  quota.limit > 0 else {
                return nil
            }
            return quota.remainingPercent
        }.min()
    }

    private static func percentText(_ value: Decimal) -> String {
        value.formatted(
            .number.precision(.fractionLength(0...1)).locale(amountLocale)
        ) + "%"
    }

    private static func title(for kind: AccountKind) -> String {
        switch kind {
        case .balance: UIStrings.providerBalanceSectionTitle
        case .subscription: UIStrings.providerQuotaSectionTitle
        }
    }
}
