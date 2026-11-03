import Foundation
import Testing

@MainActor
struct ManualRefreshTests {
    @Test
    func manualRefreshAllFetchesEveryAccount() async {
        let accounts = [
            Account(id: UUID(), provider: .deepSeek, label: "个人账户"),
            Account(id: UUID(), provider: .moonshot, label: "工作账户"),
            Account(id: UUID(), provider: .openRouter, label: "备用账户"),
        ]
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: accounts,
            now: { fixedNow }
        )

        await monitor.refresh()

        #expect(Set(provider.fetchedAccountIDs) == Set(accounts.map(\.id)))
        #expect(monitor.rows.map(\.account) == accounts)
        #expect(monitor.rows.allSatisfy { $0.snapshot != nil })
    }

    @Test
    func manualRefreshOfOneAccountFetchesOnlyThatAccount() async throws {
        let accounts = [
            Account(id: UUID(), provider: .deepSeek, label: "个人账户"),
            Account(id: UUID(), provider: .moonshot, label: "工作账户"),
            Account(id: UUID(), provider: .openRouter, label: "管理账户"),
        ]
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: accounts,
            now: { fixedNow }
        )

        await monitor.refresh(accountID: accounts[1].id)

        #expect(provider.fetchedAccountIDs == [accounts[1].id])
        #expect(monitor.rows[0].snapshot == nil)
        #expect(monitor.rows[1].snapshot?.accountID == accounts[1].id)
        #expect(monitor.rows[2].snapshot == nil)
        let refreshedRow = try #require(monitor.rows.first { $0.id == accounts[1].id })
        #expect(refreshedRow.status == .fresh)
    }

    @Test
    func manualRefreshOfAnAccountObjectUsesItsIdentity() async {
        let account = Account(id: UUID(), provider: .openRouter, label: "管理账户")
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            now: { fixedNow }
        )

        await monitor.refresh(account: account)

        #expect(provider.fetchedAccountIDs == [account.id])
        #expect(monitor.rows.first?.snapshot?.accountID == account.id)
    }

    @Test
    func manualRefreshOfAnUnknownAccountFetchesNothing() async {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            now: { fixedNow }
        )

        await monitor.refresh(accountID: UUID())

        #expect(provider.fetchedAccountIDs.isEmpty)
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
