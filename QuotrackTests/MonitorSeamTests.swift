import Foundation
import Observation
import Testing

/// The panel and menu bar depend on the BalanceMonitor interface, not the
/// live implementation. A fake monitor must be able to produce every row
/// state, and row mutations must still reach Observation consumers.
@MainActor
struct MonitorSeamTests {
    @Test
    func aFakeMonitorProducesFreshStaleErrorAndEmptyStates() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fresh = row(
            provider: .deepSeek,
            snapshotAge: 60,
            status: .fresh,
            now: now
        )
        let stale = row(
            provider: .moonshot,
            snapshotAge: 3_600,
            status: .stale,
            now: now
        )
        let failed = row(
            provider: .openRouter,
            snapshotAge: nil,
            status: .error,
            error: .permission,
            now: now
        )
        let fake = FakeMonitor()
        let monitor: any BalanceMonitor = fake

        #expect(monitor.rows.isEmpty)
        #expect(monitor.aggregateState == .normal)

        await confirmation("fake monitor row change observed through the seam") { confirm in
            withObservationTracking {
                _ = monitor.rows
            } onChange: {
                confirm()
            }
            fake.rows = [fresh, stale, failed]
        }

        #expect(monitor.rows.count == 3)
        #expect(monitor.rows.map(\.status) == [.fresh, .stale, .error])
        #expect(monitor.aggregateState == .error)
    }

    private func row(
        provider: Provider,
        snapshotAge: TimeInterval?,
        status: SnapshotStatus?,
        error: BalanceProviderError? = nil,
        now: Date
    ) -> BalanceRow {
        let account = Account(id: UUID(), provider: provider, label: "账户")
        let snapshot = snapshotAge.map { age in
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
                fetchedAt: now.addingTimeInterval(-age),
                isAvailable: true
            )
        }
        return BalanceRow(account: account, snapshot: snapshot, status: status, error: error)
    }
}

@MainActor
@Observable
private final class FakeMonitor: BalanceMonitor {
    var rows: [BalanceRow] = []
    var pollingInterval: TimeInterval = 300

    var aggregateState: AggregateBalanceState {
        AggregateBalanceState.derive(from: rows)
    }

    func startPolling() {}

    func stopPolling() {}

    func refresh() async {}

    func refresh(accountID: Account.ID) async {}
}
