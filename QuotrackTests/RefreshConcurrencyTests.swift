import Foundation
import Testing

@MainActor
struct RefreshConcurrencyTests {
    @Test(.timeLimit(.minutes(1)))
    func atMostThreeFetchesRunConcurrently() async {
        let accounts = (0..<7).map { index in
            Account(id: UUID(), provider: .deepSeek, label: "账户 \(index)")
        }
        let gate = AsyncGate()
        let provider = RecordingBalanceProvider { account in
            await gate.wait()
            return makeSnapshot(for: account)
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: accounts,
            now: { fixedNow }
        )

        let refresh = Task { await monitor.refresh() }
        await provider.waitForStartedCount(3)
        #expect(provider.peakConcurrentFetches == 3)

        await gate.open()
        await refresh.value

        #expect(provider.startedCount == 7)
        #expect(provider.peakConcurrentFetches == 3)
        #expect(monitor.rows.allSatisfy { $0.snapshot != nil })
    }

    @Test(.timeLimit(.minutes(1)))
    func concurrencyCapIsSharedByRefreshAllAndManualRefreshOfOneAccount() async {
        let accounts = (0..<6).map { index in
            Account(id: UUID(), provider: .moonshot, label: "账户 \(index)")
        }
        let gate = AsyncGate()
        let provider = RecordingBalanceProvider { account in
            await gate.wait()
            return makeSnapshot(for: account)
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: accounts,
            now: { fixedNow }
        )

        let refreshAll = Task { await monitor.refresh() }
        await provider.waitForStartedCount(3)

        let refreshOne = Task { await monitor.refresh(accountID: accounts[5].id) }

        await gate.open()
        await refreshAll.value
        await refreshOne.value

        #expect(provider.startedCount == 7)
        #expect(provider.peakConcurrentFetches == 3)
    }

    @Test(.timeLimit(.minutes(1)))
    func aHangingFailingAccountDoesNotPreventOtherAccountsFromRefreshing() async throws {
        let failingAccount = Account(id: UUID(), provider: .openRouter, label: "失败账户")
        let healthyAccounts = [
            Account(id: UUID(), provider: .deepSeek, label: "个人账户"),
            Account(id: UUID(), provider: .moonshot, label: "工作账户"),
        ]
        let failureGate = AsyncGate()
        let provider = RecordingBalanceProvider { account in
            if account.id == failingAccount.id {
                await failureGate.wait()
                throw BalanceProviderError.authentication
            }
            return makeSnapshot(for: account)
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [failingAccount] + healthyAccounts,
            now: { fixedNow }
        )

        let refresh = Task { await monitor.refresh() }
        await provider.waitForStartedCount(3)

        await failureGate.open()
        await refresh.value

        let failingRow = try #require(monitor.rows.first { $0.id == failingAccount.id })
        #expect(failingRow.error == .authentication)
        #expect(failingRow.snapshot == nil)

        for account in healthyAccounts {
            let row = try #require(monitor.rows.first { $0.id == account.id })
            #expect(row.snapshot?.accountID == account.id)
            #expect(row.status == .fresh)
            #expect(row.error == nil)
        }
    }

    @Test
    func eachAccountReportsItsOwnErrorCategory() async throws {
        let authenticationAccount = Account(id: UUID(), provider: .deepSeek, label: "认证")
        let networkAccount = Account(id: UUID(), provider: .moonshot, label: "网络")
        let malformedAccount = Account(id: UUID(), provider: .siliconFlow, label: "解析")
        let unknownAccount = Account(id: UUID(), provider: .openRouter, label: "未知")
        let healthyAccount = Account(id: UUID(), provider: .deepSeek, label: "正常")
        let accounts = [
            authenticationAccount, networkAccount, malformedAccount, unknownAccount, healthyAccount,
        ]
        let provider = RecordingBalanceProvider { account in
            switch account.id {
            case authenticationAccount.id:
                throw BalanceProviderError.authentication
            case networkAccount.id:
                throw URLError(.timedOut)
            case malformedAccount.id:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "bad JSON")
                )
            case unknownAccount.id:
                throw NSError(domain: "test", code: 1)
            default:
                return makeSnapshot(for: account)
            }
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: accounts,
            now: { fixedNow }
        )

        await monitor.refresh()

        #expect(error(for: authenticationAccount.id, in: monitor) == .authentication)
        #expect(error(for: networkAccount.id, in: monitor) == .network)
        #expect(error(for: malformedAccount.id, in: monitor) == .malformedResponse)
        #expect(error(for: unknownAccount.id, in: monitor) == .unknown)
        #expect(error(for: healthyAccount.id, in: monitor) == nil)
    }

    private func error(
        for accountID: Account.ID,
        in monitor: LiveBalanceMonitor
    ) -> BalanceProviderError? {
        monitor.rows.first { $0.id == accountID }?.error
    }
}

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

private func makeSnapshot(for account: Account) -> BalanceSnapshot {
    BalanceSnapshot(
        accountID: account.id,
        balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
        fetchedAt: fixedNow,
        isAvailable: true
    )
}
