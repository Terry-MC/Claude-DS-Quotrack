import Foundation

/// A Provider adapter that can query with a credential directly, before that
/// credential belongs to a saved Account. Real adapters conform to this in
/// addition to `BalanceProvider`, which lets the onboarding and Settings
/// connection testers share the exact production adapters.
protocol CredentialBalanceAdapter: BalanceProvider {
    func fetchBalance(region: Region?, credential: String) async throws -> BalanceSnapshot
}
