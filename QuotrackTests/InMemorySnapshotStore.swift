import Foundation

/// A thread-safe SnapshotStore for tests. It keeps everything in memory, so no
/// test ever reads or writes the real Application Support directory.
final class InMemorySnapshotStore: SnapshotStore, @unchecked Sendable {
    private let lock = NSLock()
    private var accounts: [Account]
    private var snapshots: [Account.ID: BalanceSnapshot]

    init(
        accounts: [Account] = [],
        snapshots: [Account.ID: BalanceSnapshot] = [:]
    ) {
        self.accounts = accounts
        self.snapshots = snapshots
    }

    func loadAccounts() -> [Account] {
        lock.withLock { accounts }
    }

    func saveAccounts(_ accounts: [Account]) throws {
        lock.withLock { self.accounts = accounts }
    }

    func loadSnapshots() -> [Account.ID: BalanceSnapshot] {
        lock.withLock { snapshots }
    }

    func saveSnapshot(_ snapshot: BalanceSnapshot) throws {
        lock.withLock { snapshots[snapshot.accountID] = snapshot }
    }

    func deleteAccount(id: Account.ID) throws {
        lock.withLock {
            accounts.removeAll { $0.id == id }
            snapshots[id] = nil
        }
    }
}
