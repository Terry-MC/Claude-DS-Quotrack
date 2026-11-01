import Foundation

/// The persistence seam for Account metadata and Balance Snapshots. Tests and
/// previews substitute an in-memory store; the app uses `FileSnapshotStore`,
/// which keeps everything under Application Support.
protocol SnapshotStore: Sendable {
    func loadAccounts() -> [Account]
    func saveAccounts(_ accounts: [Account]) throws
    func loadSnapshots() -> [Account.ID: BalanceSnapshot]
    func saveSnapshot(_ snapshot: BalanceSnapshot) throws
    /// Removes the Account's metadata and its persisted Snapshot. Account CRUD
    /// calls this so a deleted Account leaves nothing behind on disk.
    func deleteAccount(id: Account.ID) throws
}

/// Persists Account metadata as JSON under a directory. Writes are atomic, and
/// missing or unreadable files load as empty rather than failing the app.
struct FileSnapshotStore: SnapshotStore {
    private enum FileName {
        static let accounts = "accounts.json"
        static let snapshots = "snapshots.json"
    }

    let directoryURL: URL

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    /// The app's real store, under Application Support. Tests inject their own
    /// directory and never call this.
    static func applicationSupport(
        fileManager: FileManager = .default,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> FileSnapshotStore {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let folder = bundleIdentifier ?? "com.terry.quotrack"
        return FileSnapshotStore(
            directoryURL: base.appendingPathComponent(folder, isDirectory: true)
        )
    }

    func loadAccounts() -> [Account] {
        guard
            let data = try? Data(contentsOf: directoryURL.appendingPathComponent(FileName.accounts)),
            let accounts = try? JSONDecoder().decode([Account].self, from: data)
        else {
            return []
        }
        return accounts
    }

    func saveAccounts(_ accounts: [Account]) throws {
        let data = try JSONEncoder().encode(accounts)
        try write(data, fileName: FileName.accounts)
    }

    /// Only the last successful Snapshot per Account is kept, which is all the
    /// panel needs before its first refresh on the next launch.
    func loadSnapshots() -> [Account.ID: BalanceSnapshot] {
        guard
            let data = try? Data(contentsOf: directoryURL.appendingPathComponent(FileName.snapshots)),
            let snapshots = try? JSONDecoder().decode([BalanceSnapshot].self, from: data)
        else {
            return [:]
        }
        return Dictionary(snapshots.map { ($0.accountID, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    func saveSnapshot(_ snapshot: BalanceSnapshot) throws {
        var snapshots = loadSnapshots()
        snapshots[snapshot.accountID] = snapshot
        try writeSnapshots(snapshots)
    }

    func deleteAccount(id: Account.ID) throws {
        try saveAccounts(loadAccounts().filter { $0.id != id })
        var snapshots = loadSnapshots()
        snapshots[id] = nil
        try writeSnapshots(snapshots)
    }

    private func writeSnapshots(_ snapshots: [Account.ID: BalanceSnapshot]) throws {
        let ordered = snapshots.values.sorted { $0.accountID.uuidString < $1.accountID.uuidString }
        let data = try JSONEncoder().encode(ordered)
        try write(data, fileName: FileName.snapshots)
    }

    private func write(_ data: Data, fileName: String) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(to: directoryURL.appendingPathComponent(fileName), options: .atomic)
    }
}
