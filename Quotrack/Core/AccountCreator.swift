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

    /// Runs the connection test before any Keychain or metadata write. Both
    /// thresholds are applied after the Account exists.
    func create(
        _ draft: AccountDraft,
        thresholds: AccountThresholds
    ) async throws -> Account {
        _ = try await connectionTester.testConnection(draft)
        let account = try manager.addAccount(draft)
        guard thresholds.warning != nil || thresholds.critical != nil else {
            return account
        }
        try manager.updateThresholds(
            accountID: account.id,
            thresholds: thresholds
        )
        return account.with(thresholds: thresholds)
    }

    /// v1 compatibility wrapper until the Balance health UI migrates to
    /// `AccountThresholds`.
    func create(
        _ draft: AccountDraft,
        lowBalanceThreshold: Decimal? = nil
    ) async throws -> Account {
        try await create(
            draft,
            thresholds: AccountThresholds(warning: lowBalanceThreshold)
        )
    }
}
