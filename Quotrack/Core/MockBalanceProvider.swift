import Foundation

/// A BalanceProvider for the mock slice. It returns one fixed Balance
/// Snapshot for any Account, so the UI and monitor run without credentials,
/// network, or Keychain access.
struct MockBalanceProvider: BalanceProvider {
    static let amount = Decimal(string: "42.50")!
    static let currency = Currency.cny

    private let fetchedAt: Date

    init(fetchedAt: Date = Date()) {
        self.fetchedAt = fetchedAt
    }

    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Self.amount, currency: Self.currency),
            fetchedAt: fetchedAt,
            isAvailable: true
        )
    }
}
