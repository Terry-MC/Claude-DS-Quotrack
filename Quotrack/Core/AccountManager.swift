import Foundation
import Observation

/// Owns the Account list and coordinates Account metadata persistence with
/// Keychain-only credential storage. The Settings window talks only to this
/// type; it never reads a credential back for display.
@MainActor
@Observable
final class AccountManager {
    private(set) var accounts: [Account]
    private let store: any SnapshotStore
    private let credentialStore: any CredentialStore

    init(store: any SnapshotStore, credentialStore: any CredentialStore) {
        self.store = store
        self.credentialStore = credentialStore
        self.accounts = store.loadAccounts()
    }

    /// Adds an Account, storing the credential in the CredentialStore and the
    /// identity in the SnapshotStore. A failed metadata write rolls back the
    /// credential so no orphan secret is left behind.
    @discardableResult
    func addAccount(
        provider: Provider,
        region: Region? = nil,
        label: String,
        credential: String
    ) throws -> Account {
        let account = Account(
            id: UUID(),
            provider: provider,
            region: provider.supportsRegion ? (region ?? .domestic) : nil,
            label: label
        )
        try credentialStore.save(credential, for: account.id)
        do {
            try store.saveAccounts(accounts + [account])
        } catch {
            try? credentialStore.deleteCredential(for: account.id)
            throw error
        }
        accounts.append(account)
        return account
    }
}
