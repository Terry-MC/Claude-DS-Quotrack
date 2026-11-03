import Foundation

/// A thread-safe SnapshotStore for tests. It keeps everything in memory, so no
/// test ever reads or writes the real Application Support directory.
final class InMemorySnapshotStore: SnapshotStore, @unchecked Sendable {
    private let lock = NSLock()
    private var accounts: [Account]
    private var snapshots: [Account.ID: AccountSnapshot]

    init(
        accounts: [Account] = [],
        snapshots: [Account.ID: BalanceSnapshot] = [:]
    ) {
        self.accounts = accounts
        self.snapshots = snapshots.mapValues(AccountSnapshot.balance)
    }

    init(
        accounts: [Account] = [],
        accountSnapshots: [Account.ID: AccountSnapshot]
    ) {
        self.accounts = accounts
        self.snapshots = accountSnapshots
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
