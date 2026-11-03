import Foundation
import Testing

/// A Snapshot is Stale once it is older than three Polling Intervals. These
/// tests pin the threshold itself; a current fetch error is covered separately
/// and outranks Stale in the row and aggregate state.
@MainActor
struct StalenessTests {
    @Test(arguments: [60.0, 300.0])
    func aSnapshotIsStaleOnlyAfterThreePollingIntervals(
        interval: TimeInterval
    ) throws {
        let atBoundary = try makeRow(age: 3 * interval, interval: interval)
        #expect(atBoundary.status == .fresh)

        let pastBoundary = try makeRow(age: 3 * interval + 1, interval: interval)
        #expect(pastBoundary.status == .stale)
        #expect(pastBoundary.balanceSnapshot?.balance == lastKnownBalance)
    }

    @Test
    func stalenessUsesTheConfiguredPollingInterval() throws {
        let monitor = try makeMonitor(age: 181, interval: 300)
        #expect(monitor.rows.first?.status == .fresh)

        monitor.pollingInterval = 60

        let row = try #require(monitor.rows.first)
        #expect(row.status == .stale)
        #expect(row.snapshot != nil)
    }

    private func makeRow(
        age: TimeInterval,
        interval: TimeInterval
    ) throws -> BalanceRow {
        try #require(try makeMonitor(age: age, interval: interval).rows.first)
    }

    private func makeMonitor(
        age: TimeInterval,
        interval: TimeInterval
    ) throws -> LiveBalanceMonitor {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: lastKnownBalance,
            fetchedAt: now.addingTimeInterval(-age),
            isAvailable: true
        )
        return LiveBalanceMonitor(
            provider: RecordingBalanceProvider(snapshot: { account in
                BalanceSnapshot(
                    accountID: account.id,
                    balance: lastKnownBalance,
                    fetchedAt: now,
                    isAvailable: true
                )
            }),
            accounts: [account],
            store: InMemorySnapshotStore(snapshots: [account.id: snapshot]),
            pollingInterval: interval,
            now: { now }
        )
    }
}

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let lastKnownBalance = Balance(
    amount: Decimal(string: "42.50")!,
    currency: .cny
)
