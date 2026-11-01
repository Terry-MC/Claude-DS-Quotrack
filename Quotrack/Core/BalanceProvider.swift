/// The single adapter seam every Provider implements. The monitor never sees
/// Provider-specific request or response shapes.
protocol BalanceProvider: Sendable {
    func fetchBalance(for account: Account) async throws -> BalanceSnapshot
}
