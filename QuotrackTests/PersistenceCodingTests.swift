import Foundation
import Testing

struct PersistenceCodingTests {
    @Test
    func balanceSnapshotRoundTripsThroughJSON() throws {
        let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = BalanceSnapshot(
            accountID: accountID,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: fetchedAt,
            isAvailable: true
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BalanceSnapshot.self, from: data)

        #expect(decoded == snapshot)
        #expect(decoded.balance.amount == Decimal(string: "42.50")!)
        #expect(decoded.balance.currency == Currency(code: "CNY", symbol: "¥"))
        #expect(decoded.fetchedAt == fetchedAt)
        #expect(decoded.isAvailable)
    }
}
