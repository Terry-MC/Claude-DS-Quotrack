import Foundation

/// Mock mode's Account and Snapshot store. It keeps fixtures in memory so the
/// panel and Settings can share the same Accounts without reading or writing
/// the user's real Application Support data.
final class EphemeralSnapshotStore: SnapshotStore, @unchecked Sendable {
    private let lock = NSLock()
    private var accounts: [Account]
    private var snapshots: [Account.ID: AccountSnapshot]

    init(accounts: [Account] = []) {
        self.accounts = accounts
        self.snapshots = [:]
    }

    func loadAccounts() -> [Account] {
        lock.withLock { accounts }
    }

    func saveAccounts(_ accounts: [Account]) throws {
        lock.withLock { self.accounts = accounts }
    }

    func loadSnapshots() -> [Account.ID: AccountSnapshot] {
        lock.withLock { snapshots }
    }

    func saveSnapshot(_ snapshot: AccountSnapshot) throws {
        lock.withLock { snapshots[snapshot.accountID] = snapshot }
    }

    func deleteAccount(id: Account.ID) throws {
        lock.withLock {
            accounts.removeAll { $0.id == id }
            snapshots[id] = nil
        }
    }
}

/// Mock mode's credential store. It never writes to the real Keychain.
final class EphemeralCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var credentials: [Account.ID: String] = [:]

    func save(_ credential: String, for accountID: Account.ID) throws {
        lock.withLock { credentials[accountID] = credential }
    }

    func credential(for accountID: Account.ID) throws -> String? {
        lock.withLock { credentials[accountID] }
    }

    func deleteCredential(for accountID: Account.ID) throws {
        lock.withLock { credentials[accountID] = nil }
    }
}

/// Mock mode's settings store, so polling changes made during a demo do not
/// leak into the user's real settings file.
final class EphemeralSettingsStore: SettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var settings: AppSettings

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func loadSettings() -> AppSettings {
        lock.withLock { settings }
    }

    func saveSettings(_ settings: AppSettings) throws {
        lock.withLock { self.settings = settings }
    }
}
