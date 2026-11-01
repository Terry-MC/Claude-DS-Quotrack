import Foundation
import Observation
import Testing

@MainActor
struct BalanceMonitorTests {
    @Test
    func refreshPublishesBalanceSnapshotFromProvider() async throws {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: fetchedAt,
            isAvailable: true
        )
        let provider = FakeBalanceProvider(snapshot: snapshot)
        let monitor = LiveBalanceMonitor(provider: provider, accounts: [account])

        await monitor.refresh()

        #expect(monitor.rows.count == 1)
        let row = try #require(monitor.rows.first)
        #expect(row.account.provider == .deepSeek)
        #expect(row.account.label == "个人账户")
        #expect(row.snapshot == snapshot)
        #expect(row.status == .fresh)
    }

    @Test
    func refreshReplacesRowWithNewSnapshotFromProvider() async throws {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let firstFetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let firstSnapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: firstFetchedAt,
            isAvailable: true
        )
        let provider = FakeBalanceProvider(snapshot: firstSnapshot)
        let monitor = LiveBalanceMonitor(provider: provider, accounts: [account])
        await monitor.refresh()

        let secondSnapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "7.25")!, currency: .usd),
            fetchedAt: firstFetchedAt.addingTimeInterval(300),
            isAvailable: true
        )
        provider.snapshot = secondSnapshot

        await monitor.refresh()

        let row = try #require(monitor.rows.first)
        #expect(row.snapshot == secondSnapshot)
        #expect(row.status == .fresh)
    }

    @Test
    func mockBalanceAppearsAsOnePanelRow() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let monitor = LiveBalanceMonitor(
            provider: MockBalanceProvider(fetchedAt: now.addingTimeInterval(-120)),
            accounts: [account]
        )

        await monitor.refresh()

        let row = try #require(monitor.rows.first)
        let viewState = BalanceRowPresentation.viewState(for: row, now: now)
        #expect(viewState.providerName == "DeepSeek")
        #expect(viewState.label == "个人账户")
        #expect(viewState.balanceText == "¥42.50")
        #expect(viewState.updatedText == "2分钟前")
        #expect(viewState.statusText == "正常")
    }

    @Test
    func rowChangesNotifyObserversThroughTheMonitorSeam() async throws {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: true
        )
        let monitor: any BalanceMonitor = LiveBalanceMonitor(
            provider: FakeBalanceProvider(snapshot: snapshot),
            accounts: [account]
        )

        await confirmation("row update observed") { confirm in
            withObservationTracking {
                _ = monitor.rows
            } onChange: {
                confirm()
            }
            await monitor.refresh()
        }
    }
}

private final class FakeBalanceProvider: BalanceProvider, @unchecked Sendable {
    var snapshot: BalanceSnapshot

    init(snapshot: BalanceSnapshot) {
        self.snapshot = snapshot
    }

    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        snapshot
    }
}
