import Foundation

/// Shared fixtures for Health transition and notification tests. Rows are built
/// directly so each test controls freshness, errors, and the numeric value
/// without a Provider, clock, or network.
enum HealthTestSupport {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func balanceAccount(
        id: UUID = UUID(),
        provider: Provider = .deepSeek,
        label: String = "账户",
        currency: Currency? = .cny,
        warning: Decimal? = 10,
        critical: Decimal? = 5
    ) -> Account {
        Account(
            id: id,
            provider: provider,
            currency: currency,
            label: label,
            warningThreshold: warning,
            criticalThreshold: critical
        )
    }

    static func quotaAccount(
        id: UUID = UUID(),
        label: String = "Kimi Code",
        warning: Decimal? = 20,
        critical: Decimal? = 10
    ) -> Account {
        Account(
            id: id,
            provider: .moonshot,
            kind: .subscription,
            label: label,
            warningThreshold: warning,
            criticalThreshold: critical
        )
    }

    static func balanceRow(
        _ account: Account,
        balance: Decimal,
        status: SnapshotStatus = .fresh,
        error: BalanceProviderError? = nil
    ) -> BalanceRow {
        BalanceRow(
            account: account,
            snapshot: .balance(
                BalanceSnapshot(
                    accountID: account.id,
                    balance: Balance(
                        amount: balance,
                        currency: account.currency ?? .cny
                    ),
                    fetchedAt: now,
                    isAvailable: status != .unavailable
                )
            ),
            status: status,
            error: error
        )
    }

    /// A Quota Snapshot with a limit of 100, so the remaining amount equals the
    /// remaining percentage the Health evaluator reads.
    static func quotaRow(
        _ account: Account,
        remainingPercent: Decimal,
        status: SnapshotStatus = .fresh
    ) -> BalanceRow {
        BalanceRow(
            account: account,
            snapshot: .quota(
                QuotaSnapshot(
                    accountID: account.id,
                    limit: 100,
                    remaining: remainingPercent,
                    fetchedAt: now
                )
            ),
            status: status
        )
    }
}
