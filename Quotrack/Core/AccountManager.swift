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
        let trimmedLabel = try validatedLabel(label)
        guard !credential.isEmpty else {
            throw AccountManagerError.missingCredential
        }
        let account = Account(
            id: UUID(),
            provider: provider,
            region: provider.supportsRegion ? (region ?? .domestic) : nil,
            label: trimmedLabel
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

    /// Changes only the label. Account identity, Provider, Region, and the
    /// Keychain credential are untouched.
    func updateLabel(accountID: Account.ID, label: String) throws {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            throw AccountManagerError.accountNotFound
        }
        let trimmedLabel = try validatedLabel(label)
        let current = accounts[index]
        let updated = Account(
            id: current.id,
            provider: current.provider,
            region: current.region,
            label: trimmedLabel
        )
        var updatedAccounts = accounts
        updatedAccounts[index] = updated
        try store.saveAccounts(updatedAccounts)
        accounts = updatedAccounts
    }

    /// Replaces only the Keychain item. Account identity, label, metadata, and
    /// the persisted Balance Snapshot stay untouched.
    func replaceCredential(accountID: Account.ID, credential: String) throws {
        guard accounts.contains(where: { $0.id == accountID }) else {
            throw AccountManagerError.accountNotFound
        }
        guard !credential.isEmpty else {
            throw AccountManagerError.missingCredential
        }
        try credentialStore.save(credential, for: accountID)
    }

    /// Removes the Keychain item first so no orphan secret can survive, then
    /// the Account metadata and its persisted Snapshot through the store.
    func deleteAccount(id: Account.ID) throws {
        guard accounts.contains(where: { $0.id == id }) else {
            throw AccountManagerError.accountNotFound
        }
        try credentialStore.deleteCredential(for: id)
        try store.deleteAccount(id: id)
        accounts.removeAll { $0.id == id }
    }

    private func validatedLabel(_ label: String) throws -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AccountManagerError.missingLabel
        }
        return trimmed
    }
}

enum AccountManagerError: Error, Equatable, LocalizedError {
    case accountNotFound
    case missingLabel
    case missingCredential

    var errorDescription: String? {
        switch self {
        case .accountNotFound: "账户不存在。"
        case .missingLabel: "请填写账户标签。"
        case .missingCredential: "请填写凭证。"
        }
    }
}
