import Foundation
import Testing

struct AccountHealthTests {
    @Test
    func healthForABalanceAccountUsesWarningAndCriticalThresholds() {
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "账户",
            warningThreshold: 10,
            criticalThreshold: 5
        )

        #expect(health(for: account, balance: 20) == .normal)
        #expect(health(for: account, balance: 10) == .warning)
        #expect(health(for: account, balance: 9.99) == .warning)
        #expect(health(for: account, balance: 5) == .critical)
        #expect(health(for: account, balance: 4.99) == .critical)
        #expect(health(for: account, balance: 0) == .critical)
    }

    @Test
    func quotaHealthUsesRemainingPercentageThresholds() {
        let account = Account(
            id: UUID(),
            provider: .moonshot,
            kind: .subscription,
            label: "Kimi Code",
            warningThreshold: 20,
            criticalThreshold: 10
        )

        #expect(health(for: account, limit: 100, remaining: 30) == .normal)
        #expect(health(for: account, limit: 100, remaining: 20) == .warning)
        #expect(health(for: account, limit: 100, remaining: 10) == .critical)
        #expect(health(for: account, limit: 100, remaining: 0) == .critical)

        // A non-100 limit proves the evaluator converts remaining/limit.
        #expect(health(for: account, limit: 200, remaining: 41) == .normal)
        #expect(health(for: account, limit: 200, remaining: 40) == .warning)
        #expect(health(for: account, limit: 200, remaining: 20) == .critical)
    }

    @Test
    func healthIsUnsetWithoutASnapshotOrThresholds() {
        let noThresholds = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "账户"
        )
        let withThreshold = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "账户",
            warningThreshold: 10
        )

        #expect(health(for: noThresholds, balance: 20) == .unset)
        #expect(AccountHealthEvaluator.health(for: withThreshold, snapshot: nil) == .unset)
    }

    @Test
    func warningOnlyAndCriticalOnlyConfigureTheAvailableLevels() {
        let warningOnly = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "账户",
            warningThreshold: 10
        )
        let criticalOnly = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "账户",
            criticalThreshold: 5
        )

        #expect(health(for: warningOnly, balance: 11) == .normal)
        #expect(health(for: warningOnly, balance: 10) == .warning)
        #expect(health(for: warningOnly, balance: 1) == .warning)
        #expect(health(for: criticalOnly, balance: 6) == .normal)
        #expect(health(for: criticalOnly, balance: 5) == .critical)
    }

    @Test
    func quotaWarningOnlyAndCriticalOnlyConfigureTheAvailableLevels() {
        let warningOnly = Account(
            id: UUID(),
            provider: .moonshot,
            kind: .subscription,
            label: "Kimi Code",
            warningThreshold: 20
        )
        let criticalOnly = Account(
            id: UUID(),
            provider: .moonshot,
            kind: .subscription,
            label: "Kimi Code",
            criticalThreshold: 10
        )
        let noThresholds = Account(
            id: UUID(),
            provider: .moonshot,
            kind: .subscription,
            label: "Kimi Code"
        )

        #expect(health(for: warningOnly, limit: 100, remaining: 21) == .normal)
        #expect(health(for: warningOnly, limit: 100, remaining: 20) == .warning)
        #expect(health(for: warningOnly, limit: 100, remaining: 1) == .warning)
        #expect(health(for: criticalOnly, limit: 100, remaining: 11) == .normal)
        #expect(health(for: criticalOnly, limit: 100, remaining: 10) == .critical)
        #expect(health(for: noThresholds, limit: 100, remaining: 50) == .unset)
    }

    @Test
    func aSnapshotWhoseKindDoesNotMatchTheAccountIsUnset() {
        let balanceAccount = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "账户",
            warningThreshold: 10
        )
        let quotaSnapshot = AccountSnapshot.quota(
            QuotaSnapshot(
                accountID: balanceAccount.id,
                limit: 100,
                remaining: 0,
                fetchedAt: now
            )
        )

        #expect(AccountHealthEvaluator.health(for: balanceAccount, snapshot: quotaSnapshot) == .unset)
    }

    @Test
    func unavailableBalanceAndCurrencyMismatchAreUnset() {
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            currency: .cny,
            label: "账户",
            warningThreshold: 10
        )
        let unavailable = AccountSnapshot.balance(
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: 0, currency: .cny),
                fetchedAt: now,
                isAvailable: false
            )
        )
        let wrongCurrency = AccountSnapshot.balance(
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: 0, currency: .usd),
                fetchedAt: now,
                isAvailable: true
            )
        )

        #expect(AccountHealthEvaluator.health(for: account, snapshot: unavailable) == .unset)
        #expect(AccountHealthEvaluator.health(for: account, snapshot: wrongCurrency) == .unset)
    }

    @Test
    func anInvalidThresholdPairIsUnset() {
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "账户",
            warningThreshold: 5,
            criticalThreshold: 10
        )

        #expect(health(for: account, balance: 7) == .unset)
    }

    @Test
    func worstIgnoresUnsetAndPicksTheHighestSeverity() {
        #expect(AccountHealthEvaluator.worst([]) == .unset)
        #expect(AccountHealthEvaluator.worst([.unset, .unset]) == .unset)
        #expect(AccountHealthEvaluator.worst([.unset, .normal]) == .normal)
        #expect(AccountHealthEvaluator.worst([.normal, .warning]) == .warning)
        #expect(AccountHealthEvaluator.worst([.critical, .warning]) == .critical)
    }

    private func health(for account: Account, balance: Decimal) -> AccountHealth {
        let snapshot = AccountSnapshot.balance(
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: balance, currency: .cny),
                fetchedAt: now,
                isAvailable: true
            )
        )
        return AccountHealthEvaluator.health(for: account, snapshot: snapshot)
    }

    private func health(
        for account: Account,
        limit: Decimal,
        remaining: Decimal
    ) -> AccountHealth {
        let snapshot = AccountSnapshot.quota(
            QuotaSnapshot(
                accountID: account.id,
                limit: limit,
                remaining: remaining,
                fetchedAt: now
            )
        )
        return AccountHealthEvaluator.health(for: account, snapshot: snapshot)
    }
}

private let now = Date(timeIntervalSince1970: 1_800_000_000)
