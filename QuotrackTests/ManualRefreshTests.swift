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

    @Test
    func manualRefreshOfOneProviderFetchesOnlyThatProvidersAccounts() async {
        let deepSeekAccounts = [
            Account(id: UUID(), provider: .deepSeek, label: "个人账户"),
            Account(id: UUID(), provider: .deepSeek, label: "工作账户"),
        ]
        let moonshot = Account(id: UUID(), provider: .moonshot, label: "Kimi 账户")
        let openRouter = Account(id: UUID(), provider: .openRouter, label: "管理账户")
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: deepSeekAccounts + [moonshot, openRouter],
            now: { fixedNow }
        )

        await monitor.refresh(provider: .deepSeek)

        #expect(Set(provider.fetchedAccountIDs) == Set(deepSeekAccounts.map(\.id)))
        #expect(monitor.rows[0].snapshot != nil)
        #expect(monitor.rows[1].snapshot != nil)
        #expect(monitor.rows[2].snapshot == nil)
        #expect(monitor.rows[3].snapshot == nil)
    }

    @Test
    func manualRefreshOfAProviderFetchesBothOfItsAccountKinds() async {
        let balanceAccount = Account(
            id: UUID(),
            provider: .moonshot,
            label: "Kimi 充值"
        )
        let quotaAccount = Account(
            id: UUID(),
            provider: .moonshot,
            kind: .subscription,
            label: "Kimi Code"
        )
        let other = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [balanceAccount, quotaAccount, other],
            now: { fixedNow }
        )

        await monitor.refresh(provider: .moonshot)

        #expect(
            Set(provider.fetchedAccountIDs)
                == Set([balanceAccount.id, quotaAccount.id])
        )
        #expect(monitor.rows[2].snapshot == nil)
    }

    @Test
    func manualRefreshOfAProviderWithNoAccountsFetchesNothing() async {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            now: { fixedNow }
        )

        await monitor.refresh(provider: .openRouter)

        #expect(provider.fetchedAccountIDs.isEmpty)
    }

    @Test
    func manualRefreshOfAnUnsupportedProviderFetchesNoLegacyAccount() async {
        let legacy = Account(
            id: UUID(),
            provider: .siliconFlow,
            label: "旧账户"
        )
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [legacy],
            now: { fixedNow }
        )

        await monitor.refresh(provider: .siliconFlow)

        #expect(provider.fetchedAccountIDs.isEmpty)
        #expect(monitor.rows[0].snapshot == nil)
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
