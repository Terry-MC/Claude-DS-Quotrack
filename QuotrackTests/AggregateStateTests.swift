import Foundation
import Testing

/// The menu bar aggregate is derived from the same row presentation the panel
/// uses, so a warning color and a warning icon can never disagree.
struct AggregateStateTests {
    @Test
    func noAccountsIsNormal() {
        #expect(AggregateBalanceState.derive(from: []) == .normal)
    }

    @Test
    func allFreshBalancesAboveThresholdAreNormal() {
        let rows = [
            makeRow(status: .fresh, threshold: "10", amount: "10.01"),
            makeRow(status: .fresh, amount: "0.01"),
        ]

        #expect(AggregateBalanceState.derive(from: rows) == .normal)
    }

    @Test
    func aFreshBalanceAtTheWarningLineIsWarning() {
        let rows = [
            makeRow(status: .fresh, threshold: "10", amount: "10"),
        ]

        #expect(AggregateBalanceState.derive(from: rows) == .warning)
    }

    @Test
    func anyFreshBalanceBelowThresholdIsWarning() {
        let rows = [
            makeRow(status: .fresh, amount: "100"),
            makeRow(status: .fresh, threshold: "10", amount: "9.99"),
        ]

        #expect(AggregateBalanceState.derive(from: rows) == .warning)
    }

    @Test
    func anyFreshBalanceAtTheCriticalLineIsCritical() {
        let rows = [
            makeRow(
                status: .fresh,
                threshold: "10",
                critical: "5",
                amount: "5"
            ),
        ]

        #expect(AggregateBalanceState.derive(from: rows) == .critical)
    }

    @Test
    func aStaleSnapshotKeepsItsCriticalHealthInTheAggregate() {
        let rows = [
            makeRow(
                status: .stale,
                threshold: "10",
                critical: "5",
                amount: "5"
            ),
        ]

        #expect(AggregateBalanceState.derive(from: rows) == .critical)
    }

    @Test
    func errorOutranksCritical() {
        let rows = [
            makeRow(
                status: .fresh,
                threshold: "10",
                critical: "5",
                amount: "5"
            ),
            makeRow(status: .error, error: .network),
        ]

        #expect(AggregateBalanceState.derive(from: rows) == .error)
    }

    @Test
    func anyStaleSnapshotIsWarning() {
        let rows = [
            makeRow(status: .fresh, amount: "100"),
            makeRow(status: .stale, amount: "100"),
        ]

        #expect(AggregateBalanceState.derive(from: rows) == .warning)
    }

    @Test
    func anyErrorIsError() {
        let rows = [
            makeRow(status: .fresh, amount: "100"),
            makeRow(status: .error, error: .network),
        ]

        #expect(AggregateBalanceState.derive(from: rows) == .error)
    }

    @Test
    func errorOutranksAWarning() {
        let rows = [
            makeRow(status: .fresh, threshold: "10", amount: "1"),
            makeRow(status: .error, error: .authentication),
        ]

        #expect(AggregateBalanceState.derive(from: rows) == .error)
    }

    @Test
    func anUnavailableSnapshotIsAWarning() {
        let rows = [makeRow(status: .unavailable, amount: "100", isAvailable: false)]

        #expect(AggregateBalanceState.derive(from: rows) == .warning)
    }

    @Test
    func aRowThatHasNotLoadedYetIsNotAWarning() {
        let rows = [makeRow(status: nil)]

        #expect(AggregateBalanceState.derive(from: rows) == .normal)
    }

    @Test
    func aCurrentErrorOutranksAStaleSnapshot() {
        let rows = [makeRow(status: .stale, error: .network)]

        #expect(AggregateBalanceState.derive(from: rows) == .error)
    }
}

@MainActor
struct MonitorAggregateStateTests {
    @Test
    func monitorAggregateStateReflectsTheAccountThreshold() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户",
            warningThreshold: Decimal(string: "10")
        )
        let provider = RecordingBalanceProvider { account in
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: Decimal(string: "5.00")!, currency: .cny),
                fetchedAt: now,
                isAvailable: true
            )
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            now: { now }
        )

        await monitor.refresh()

        #expect(monitor.aggregateState == .warning)
    }

    @Test
    func monitorAggregateStateIsNormalWhenFreshBalancesAreAboveThreshold() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户",
            warningThreshold: Decimal(string: "10")
        )
        let provider = RecordingBalanceProvider { account in
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: Decimal(string: "50.00")!, currency: .cny),
                fetchedAt: now,
                isAvailable: true
            )
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            now: { now }
        )

        await monitor.refresh()

        #expect(monitor.aggregateState == .normal)
    }

    @Test
    func monitorAggregateStateIsWarningWhenThePersistedSnapshotIsStale() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .moonshot, label: "Kimi 主账号")
        let staleSnapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-3_600),
            isAvailable: true
        )
        let store = InMemorySnapshotStore(
            accounts: [account],
            snapshots: [account.id: staleSnapshot]
        )
        let monitor = LiveBalanceMonitor(
            provider: RecordingBalanceProvider { _ in throw BalanceProviderError.network },
            accounts: [account],
            store: store,
            pollingInterval: 300,
            now: { now }
        )

        #expect(monitor.rows.first?.status == .stale)
        #expect(monitor.aggregateState == .warning)
    }

    @Test
    func aCurrentFetchErrorOutranksAStalePersistedSnapshot() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .moonshot, label: "Kimi 主账号")
        let staleSnapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-3_600),
            isAvailable: true
        )
        let store = InMemorySnapshotStore(
            accounts: [account],
            snapshots: [account.id: staleSnapshot]
        )
        let monitor = LiveBalanceMonitor(
            provider: RecordingBalanceProvider { _ in throw BalanceProviderError.network },
            accounts: [account],
            store: store,
            pollingInterval: 300,
            now: { now }
        )
        #expect(monitor.rows.first?.status == .stale)

        await monitor.refresh()

        let row = try #require(monitor.rows.first)
        #expect(row.status == .error)
        #expect(row.error == .network)
        #expect(BalanceRowPresentation.tone(for: row) == .error)
        #expect(monitor.aggregateState == .error)
    }

    @Test
    func monitorAggregateStateIsObservableWhenRefreshChangesIt() async {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let provider = RecordingBalanceProvider { _ in
            throw BalanceProviderError.network
        }
        let monitor = LiveBalanceMonitor(provider: provider, accounts: [account])
        #expect(monitor.aggregateState == .normal)

        await confirmation("menu bar aggregate changed without opening the panel") { confirm in
            withObservationTracking {
                _ = monitor.aggregateState
            } onChange: {
                confirm()
            }
            await monitor.refresh()
        }

        #expect(monitor.aggregateState == .error)
    }
}

private func makeRow(
    status: SnapshotStatus?,
    threshold: String? = nil,
    critical: String? = nil,
    amount: String = "10",
    isAvailable: Bool = true,
    error: BalanceProviderError? = nil
) -> BalanceRow {
    let account = Account(
        id: UUID(),
        provider: .deepSeek,
        label: "账户",
        warningThreshold: threshold.flatMap { Decimal(string: $0) },
        criticalThreshold: critical.flatMap { Decimal(string: $0) }
    )
    let snapshot = status.map { _ in
        AccountSnapshot.balance(
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: Decimal(string: amount)!, currency: .cny),
                fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
                isAvailable: isAvailable
            )
        )
    }
    return BalanceRow(account: account, snapshot: snapshot, status: status, error: error)
}
