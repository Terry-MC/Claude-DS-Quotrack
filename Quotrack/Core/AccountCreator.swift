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

    /// Validates thresholds before the connection test, then tests the
    /// credential before any Keychain or metadata write. Both thresholds are
    /// applied after the Account exists, including an explicit empty pair that
    /// clears the Kind's default.
    func create(
        _ draft: AccountDraft,
        thresholds: AccountThresholds = AccountThresholds()
    ) async throws -> Account {
        do {
            try thresholds.validate(for: draft.kind)
        } catch is AccountThresholdError {
            throw AccountManagerError.invalidThreshold
        }
        let testedSnapshot = try await connectionTester.testConnection(draft)
        let resolvedCurrency = draft.kind == .balance
            ? (draft.currency ?? testedSnapshot.balanceSnapshot?.balance.currency)
            : nil
        let savedDraft = AccountDraft(
            provider: draft.provider,
            region: draft.region,
            label: draft.label,
            credential: draft.credential,
            kind: draft.kind,
            currency: resolvedCurrency
        )
        return try manager.addAccount(savedDraft, thresholds: thresholds)
    }

}
