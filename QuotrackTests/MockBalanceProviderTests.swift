import Foundation
import Testing

struct MockBalanceProviderTests {
    @Test
    func returnsOneFixedBalanceSnapshotForTheAccount() async throws {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = MockBalanceProvider(fetchedAt: fetchedAt)

        let first = try await provider.fetchBalance(for: account)
        let second = try await provider.fetchBalance(for: account)

        #expect(first.accountID == account.id)
        #expect(first.balance == Balance(amount: Decimal(string: "42.50")!, currency: .cny))
        #expect(first.fetchedAt == fetchedAt)
        #expect(first.isAvailable)
        #expect(first == second)
    }
}
