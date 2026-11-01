import Foundation

/// Tests a draft credential and only then saves the Account. Settings and
/// onboarding both use this path, so an Account is never created for a
/// credential the Provider rejects.
@MainActor
struct AccountCreator {
    private let manager: AccountManager
    private let connectionTester: any ConnectionTesting

    init(manager: AccountManager, connectionTester: any ConnectionTesting) {
        self.manager = manager
        self.connectionTester = connectionTester
    }

    /// Runs the connection test before any Keychain or metadata write. The
    /// optional threshold is applied after the Account exists.
    func create(
        _ draft: AccountDraft,
        lowBalanceThreshold: Decimal? = nil
    ) async throws -> Account {
        _ = try await connectionTester.testConnection(draft)
        let account = try manager.addAccount(draft)
        guard let lowBalanceThreshold else {
            return account
        }
        try manager.updateLowBalanceThreshold(
            accountID: account.id,
            threshold: lowBalanceThreshold
        )
        return account.with(lowBalanceThreshold: lowBalanceThreshold)
    }
}
