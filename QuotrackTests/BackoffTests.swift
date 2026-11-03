import Foundation
import Testing

@MainActor
struct BackoffTests {
    @Test(.timeLimit(.minutes(1)))
    func failedAccountBacksOffAtOneTwoFiveThenFifteenMinutes() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let provider = RecordingBalanceProvider { _ in
            throw BalanceProviderError.network
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            pollingInterval: 300,
            clock: clock
        )
        monitor.startPolling()
        defer { monitor.stopPolling() }

        await clock.waitForSleepCount(1)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(300))

        clock.advance(by: 300)
        await provider.waitForStartedCount(1)
        await clock.waitForSleepCount(2)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(360))

        clock.advance(by: 60)
        await provider.waitForStartedCount(2)
        await clock.waitForSleepCount(3)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(480))

        clock.advance(by: 120)
        await provider.waitForStartedCount(3)
        await clock.waitForSleepCount(4)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(780))

        clock.advance(by: 300)
        await provider.waitForStartedCount(4)
        await clock.waitForSleepCount(5)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(1_680))

        clock.advance(by: 900)
        await provider.waitForStartedCount(5)
        await clock.waitForSleepCount(6)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(2_580))
    }

    @Test(.timeLimit(.minutes(1)))
    func successResetsTheBackoffSchedule() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
        let account = Account(id: UUID(), provider: .moonshot, label: "Kimi 主账号")
        let fetchCount = FetchCounter()
        let provider = RecordingBalanceProvider { account in
            if fetchCount.next() == 4 {
                return BalanceSnapshot(
                    accountID: account.id,
                    balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
                    fetchedAt: clock.now,
                    isAvailable: true
                )
            }
            throw BalanceProviderError.network
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            pollingInterval: 300,
            clock: clock
        )
        monitor.startPolling()
        defer { monitor.stopPolling() }

        await clock.waitForSleepCount(1)
        clock.advance(by: 300)
        await provider.waitForStartedCount(1)
        await clock.waitForSleepCount(2)

        clock.advance(by: 60)
        await provider.waitForStartedCount(2)
        await clock.waitForSleepCount(3)

        clock.advance(by: 120)
        await provider.waitForStartedCount(3)
        await clock.waitForSleepCount(4)

        clock.advance(by: 300)
        await provider.waitForStartedCount(4)
        await clock.waitForSleepCount(5)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(1_080))

        clock.advance(by: 300)
        await provider.waitForStartedCount(5)
        await clock.waitForSleepCount(6)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(1_140))
    }

    @Test(.timeLimit(.minutes(1)))
    func accountsBackOffIndependently() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
        let failingAccount = Account(id: UUID(), provider: .openRouter, label: "失败账户")
        let healthyAccount = Account(id: UUID(), provider: .deepSeek, label: "正常账户")
        let log = FetchLog()
        let provider = RecordingBalanceProvider { account in
            log.record(account.id, at: clock.now)
            if account.id == failingAccount.id {
                throw BalanceProviderError.network
            }
            return BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
                fetchedAt: clock.now,
                isAvailable: true
            )
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [failingAccount, healthyAccount],
            pollingInterval: 300,
            clock: clock
        )
        monitor.startPolling()
        defer { monitor.stopPolling() }

        await clock.waitForSleepCount(1)
        clock.advance(by: 300)
        await provider.waitForStartedCount(2)
        await clock.waitForSleepCount(2)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(360))

        clock.advance(by: 60)
        await provider.waitForStartedCount(3)
        await clock.waitForSleepCount(3)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(480))

        #expect(log.times(for: failingAccount.id) == [
            start.addingTimeInterval(300),
            start.addingTimeInterval(360),
        ])
        #expect(log.times(for: healthyAccount.id) == [start.addingTimeInterval(300)])
    }

    @Test(.timeLimit(.minutes(1)))
    func manualRefreshOfOneAccountBypassesBackoff() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let log = FetchLog()
        let provider = RecordingBalanceProvider { account in
            log.record(account.id, at: clock.now)
            throw BalanceProviderError.authentication
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            pollingInterval: 300,
            clock: clock
        )
        monitor.startPolling()
        defer { monitor.stopPolling() }

        await clock.waitForSleepCount(1)
        clock.advance(by: 300)
        await provider.waitForStartedCount(1)
        await clock.waitForSleepCount(2)

        await monitor.refresh(accountID: account.id)

        #expect(provider.startedCount == 2)
        #expect(log.times(for: account.id) == [
            start.addingTimeInterval(300),
            start.addingTimeInterval(300),
        ])
    }

    @Test(.timeLimit(.minutes(1)), arguments: [
        (BalanceProviderError.rateLimit(retryAfter: 120), TimeInterval(120)),
        (BalanceProviderError.rateLimit, TimeInterval(60)),
    ])
    func rateLimitUsesRetryAfterWhenPresentOtherwiseNormalBackoff(
        error: BalanceProviderError,
        firstRetryDelay: TimeInterval
    ) async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestPollingClock(now: start)
        let account = Account(id: UUID(), provider: .deepSeek, label: "限流账户")
        let provider = RecordingBalanceProvider { _ in
            throw error
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            pollingInterval: 300,
            clock: clock
        )
        monitor.startPolling()
        defer { monitor.stopPolling() }

        await clock.waitForSleepCount(1)
        clock.advance(by: 300)
        await provider.waitForStartedCount(1)
        await clock.waitForSleepCount(2)

        #expect(
            clock.nextSleepDeadline
                == start.addingTimeInterval(300 + firstRetryDelay)
        )
        let row = try #require(monitor.rows.first)
        #expect(row.error?.category == .rateLimit)
        #expect(row.error?.retryAfter == error.retryAfter)
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

private final class FetchLog: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [(accountID: Account.ID, date: Date)] = []

    func record(_ accountID: Account.ID, at date: Date) {
        lock.withLock {
            entries.append((accountID, date))
        }
    }

    func times(for accountID: Account.ID) -> [Date] {
        lock.withLock {
            entries.filter { $0.accountID == accountID }.map(\.date)
        }
    }
}
