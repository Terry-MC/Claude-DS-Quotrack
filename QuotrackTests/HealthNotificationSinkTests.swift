import Foundation
import Testing

/// Notifications are computed once per completed refresh, never per row.
@MainActor
struct HealthNotificationSinkTests {
    @Test
    func aFullRefreshCallsTheSinkOnceWithEveryRow() async {
        let accounts = [
            Account(id: UUID(), provider: .deepSeek, label: "个人账户"),
            Account(id: UUID(), provider: .deepSeek, label: "工作账户"),
        ]
        let sink = RecordingHealthNotificationSink()
        let monitor = LiveBalanceMonitor(
            provider: RecordingBalanceProvider(snapshot: makeSnapshot),
            accounts: accounts,
            now: { HealthTestSupport.now }
        )
        monitor.healthNotificationSink = sink

        await monitor.refresh()

        #expect(sink.batches.count == 1)
        #expect(sink.batches.first?.map(\.id) == accounts.map(\.id))
    }

    @Test
    func aPerAccountRefreshStillCallsTheSinkOnceWithTheWholeRowSet() async {
        let accounts = [
            Account(id: UUID(), provider: .deepSeek, label: "个人账户"),
            Account(id: UUID(), provider: .deepSeek, label: "工作账户"),
        ]
        let sink = RecordingHealthNotificationSink()
        let monitor = LiveBalanceMonitor(
            provider: RecordingBalanceProvider(snapshot: makeSnapshot),
            accounts: accounts,
            now: { HealthTestSupport.now }
        )
        monitor.healthNotificationSink = sink

        await monitor.refresh(accountID: accounts[1].id)

        #expect(sink.batches.count == 1)
        #expect(sink.batches.first?.map(\.id) == accounts.map(\.id))
    }

    @Test
    func aRefreshWithNoPollableAccountsCallsTheSinkOnceWithNoRows() async {
        let sink = RecordingHealthNotificationSink()
        let monitor = LiveBalanceMonitor(
            provider: RecordingBalanceProvider(snapshot: makeSnapshot),
            accounts: [],
            now: { HealthTestSupport.now }
        )
        monitor.healthNotificationSink = sink

        await monitor.refresh()

        #expect(sink.batches == [[]])
    }
}

@MainActor
private final class RecordingHealthNotificationSink: HealthNotificationSink {
    private(set) var batches: [[BalanceRow]] = []

    func pollDidComplete(rows: [BalanceRow]) {
        batches.append(rows)
    }
}

private func makeSnapshot(for account: Account) -> BalanceSnapshot {
    BalanceSnapshot(
        accountID: account.id,
        balance: Balance(
            amount: Decimal(string: "42.50")!,
            currency: .cny
        ),
        fetchedAt: HealthTestSupport.now,
        isAvailable: true
    )
}
