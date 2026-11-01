import Foundation
import Testing

@MainActor
struct StalenessTests {
    @Test(.timeLimit(.minutes(1)), arguments: [60.0, 300.0])
    func snapshotBecomesStaleAfterThreePollingIntervalsWithoutSuccess(
        interval: TimeInterval
    ) async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let lastKnownBalance = Balance(amount: Decimal(string: "42.50")!, currency: .cny)
        let fetchCount = FetchCounter()
        let provider = RecordingBalanceProvider { account in
            if fetchCount.next() == 1 {
                return BalanceSnapshot(
                    accountID: account.id,
                    balance: lastKnownBalance,
                    fetchedAt: clock.now,
                    isAvailable: true
                )
            }
            throw BalanceProviderError.network
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            pollingInterval: interval,
            clock: clock
        )
        monitor.startPolling()
        defer { monitor.stopPolling() }

        await clock.waitForSleepCount(1)
        clock.advance(by: interval)
        await provider.waitForStartedCount(1)
        await clock.waitForSleepCount(2)
        let freshRow = try #require(monitor.rows.first)
        #expect(freshRow.status == .fresh)

        clock.advance(by: 3 * interval)
        await provider.waitForStartedCount(2)
        await clock.waitForSleepCount(3)

        let staleRow = try #require(monitor.rows.first)
        #expect(staleRow.status == .stale)
        #expect(staleRow.snapshot?.balance == lastKnownBalance)
    }
}

private final class FetchCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func next() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}
