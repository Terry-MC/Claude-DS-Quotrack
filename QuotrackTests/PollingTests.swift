import Foundation
import Testing

@MainActor
struct PollingTests {
    @Test
    func pollingDefaultsToFiveMinutes() {
        #expect(LiveBalanceMonitor.defaultPollingInterval == 300)
        #expect(
            LiveBalanceMonitor(provider: NoopProvider(), accounts: []).pollingInterval == 300
        )
    }

    @Test
    func pollsEveryConfiguredIntervalUsingTheInjectedClock() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let provider = RecordingBalanceProvider { account in
            BalanceSnapshot(
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
            clock: clock
        )

        monitor.startPolling()
        await clock.waitForSleepCount(1)

        clock.advance(by: 299)
        #expect(provider.startedCount == 0)

        clock.advance(by: 1)
        await provider.waitForStartedCount(1)
        #expect(provider.fetchedAccountIDs == [account.id])

        await clock.waitForSleepCount(2)
        clock.advance(by: 300)
        await provider.waitForStartedCount(2)
        #expect(provider.startedCount == 2)

        monitor.stopPolling()
    }

    @Test(.timeLimit(.minutes(1)))
    func changingPollingIntervalReschedulesThePendingWait() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
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
            clock: clock
        )

        monitor.startPolling()
        await clock.waitForSleepCount(1)

        monitor.pollingInterval = 60
        await clock.waitForSleepCount(2)

        clock.advance(by: 60)
        await provider.waitForStartedCount(1)

        #expect(provider.startedCount == 1)
        monitor.stopPolling()
    }
}

private struct NoopProvider: BalanceProvider {
    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        throw BalanceProviderError.unknown
    }
}
