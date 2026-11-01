import Foundation
import Testing

@MainActor
struct SleepWakeTests {
    @Test(.timeLimit(.minutes(1)))
    func sleepSuspendsPollingAndWakeRefreshesImmediately() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
        let observer = FakeSleepWakeObserver()
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let fetchLog = SleepFetchLog()
        let provider = RecordingBalanceProvider { account in
            fetchLog.record(at: clock.now)
            return BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
                fetchedAt: clock.now,
                isAvailable: true
            )
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            pollingInterval: 300,
            clock: clock,
            sleepWakeObserver: observer
        )
        monitor.startPolling()
        defer { monitor.stopPolling() }
        #expect(observer.startCount == 1)

        await clock.waitForSleepCount(1)
        clock.advance(by: 300)
        await provider.waitForStartedCount(1)
        await clock.waitForSleepCount(2)

        observer.send(.willSleep)
        #expect(clock.nextSleepDeadline == nil)

        clock.advance(by: 1_200)
        #expect(provider.startedCount == 1)

        observer.send(.didWake)
        await provider.waitForStartedCount(2)
        await clock.waitForSleepCount(3)

        #expect(fetchLog.times == [
            start.addingTimeInterval(300),
            start.addingTimeInterval(1_500),
        ])
        #expect(monitor.rows.first?.status == .fresh)
    }

    @Test
    func stoppingPollingStopsObservingWakeEvents() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
        let observer = FakeSleepWakeObserver()
        let account = Account(id: UUID(), provider: .moonshot, label: "Kimi 主账号")
        let provider = RecordingBalanceProvider { account in
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: Decimal(string: "12.00")!, currency: .cny),
                fetchedAt: clock.now,
                isAvailable: true
            )
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            pollingInterval: 300,
            clock: clock,
            sleepWakeObserver: observer
        )
        monitor.startPolling()
        await clock.waitForSleepCount(1)

        monitor.stopPolling()

        #expect(observer.stopCount == 1)
        observer.send(.didWake)
        #expect(provider.startedCount == 0)
    }
}

@MainActor
private final class FakeSleepWakeObserver: SleepWakeObserving {
    private var handler: (@MainActor (SleepWakeEvent) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(on event: @escaping @MainActor (SleepWakeEvent) -> Void) {
        handler = event
        startCount += 1
    }

    func stop() {
        handler = nil
        stopCount += 1
    }

    func send(_ event: SleepWakeEvent) {
        handler?(event)
    }
}

private final class SleepFetchLog: @unchecked Sendable {
    private let lock = NSLock()
    private var dates: [Date] = []

    func record(at date: Date) {
        lock.withLock {
            dates.append(date)
        }
    }

    var times: [Date] {
        lock.withLock { dates }
    }
}
