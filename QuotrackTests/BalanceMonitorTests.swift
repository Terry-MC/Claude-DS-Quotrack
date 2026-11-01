import Foundation
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
