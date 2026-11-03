import Foundation
import Testing

struct FileSnapshotStoreTests {
    @Test
    func accountMetadataRoundTripsAcrossRelaunch() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let accounts = [
            Account(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                provider: .deepSeek,
                label: "个人账户"
            ),
            Account(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                provider: .openRouter,
                label: "工作账户"
            ),
        ]
        let store = FileSnapshotStore(directoryURL: directory)
        try store.saveAccounts(accounts)

        let relaunched = FileSnapshotStore(directoryURL: directory)

        #expect(relaunched.loadAccounts() == accounts)
    }

    @Test
    func v1BalanceSnapshotJSONLoadsAsABalanceAccountSnapshot() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
        let snapshot = BalanceSnapshot(
            accountID: accountID,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: true
        )
        // The v1 file was an array of BalanceSnapshots with no `kind` key.
        let legacyData = try JSONEncoder().encode([snapshot])
        try legacyData.write(to: directory.appendingPathComponent("snapshots.json"))

        let store = FileSnapshotStore(directoryURL: directory)

        #expect(store.loadSnapshots() == [accountID: .balance(snapshot)])
    }

    @Test
    func quotaSnapshotRoundTripsAcrossRelaunch() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        let resetAt = Date(timeIntervalSince1970: 1_800_000_300)
        let snapshot = QuotaSnapshot(
            accountID: accountID,
            limit: 100,
            remaining: 60,
            resetAt: resetAt,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            packages: [
                QuotaPackage(
                    name: "Kimi Code",
                    limit: 100,
                    remaining: 60,
                    expiresAt: resetAt
                ),
            ]
        )
        let store = FileSnapshotStore(directoryURL: directory)
        try store.saveSnapshot(.quota(snapshot))

        let relaunched = FileSnapshotStore(directoryURL: directory)

        #expect(relaunched.loadSnapshots() == [accountID: .quota(snapshot)])
    }

    @Test
    func snapshotsRoundTripAcrossRelaunch() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let accountID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let snapshot = BalanceSnapshot(
            accountID: accountID,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: true
        )
        let store = FileSnapshotStore(directoryURL: directory)
        try store.saveSnapshot(snapshot)

        let relaunched = FileSnapshotStore(directoryURL: directory)

        #expect(relaunched.loadBalanceSnapshots() == [accountID: snapshot])
    }

    @Test
    func savingASnapshotReplacesThePersistedSnapshotForThatAccount() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let accountID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let older = BalanceSnapshot(
            accountID: accountID,
            balance: Balance(amount: Decimal(string: "10.00")!, currency: .cny),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: true
        )
        let newer = BalanceSnapshot(
            accountID: accountID,
            balance: Balance(amount: Decimal(string: "7.25")!, currency: .usd),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_300),
            isAvailable: true
        )
        let store = FileSnapshotStore(directoryURL: directory)
        try store.saveSnapshot(older)
        try store.saveSnapshot(newer)

        let relaunched = FileSnapshotStore(directoryURL: directory)

        #expect(relaunched.loadBalanceSnapshots() == [accountID: newer])
    }

    @Test
    func deletingAnAccountRemovesItsMetadataAndSnapshot() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let kept = Account(id: UUID(), provider: .deepSeek, label: "保留账户")
        let deleted = Account(id: UUID(), provider: .moonshot, label: "删除账户")
        let keptSnapshot = BalanceSnapshot(
            accountID: kept.id,
            balance: Balance(amount: Decimal(string: "12.00")!, currency: .cny),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: true
        )
        let deletedSnapshot = BalanceSnapshot(
            accountID: deleted.id,
            balance: Balance(amount: Decimal(string: "9.00")!, currency: .usd),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: true
        )
        let store = FileSnapshotStore(directoryURL: directory)
        try store.saveAccounts([kept, deleted])
        try store.saveSnapshot(keptSnapshot)
        try store.saveSnapshot(deletedSnapshot)

        try store.deleteAccount(id: deleted.id)

        let relaunched = FileSnapshotStore(directoryURL: directory)
        #expect(relaunched.loadAccounts() == [kept])
        #expect(relaunched.loadBalanceSnapshots() == [kept.id: keptSnapshot])
    }

    @Test
    func missingFilesLoadAsEmpty() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileSnapshotStore(directoryURL: directory)

        #expect(store.loadAccounts().isEmpty)
        #expect(store.loadSnapshots().isEmpty)
    }

    @Test
    func corruptFilesLoadAsEmptyWithoutCrashing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: true
        )
        let store = FileSnapshotStore(directoryURL: directory)
        try store.saveAccounts([account])
        try store.saveSnapshot(snapshot)

        for file in try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) {
            try Data("{\"broken\":".utf8).write(to: file)
        }

        #expect(store.loadAccounts().isEmpty)
        #expect(store.loadSnapshots().isEmpty)
    }

    @Test
    func failedAtomicWriteLeavesPreviousDataIntact() throws {
        let directory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path
            )
            try? FileManager.default.removeItem(at: directory)
        }

        let original = [Account(id: UUID(), provider: .deepSeek, label: "原始账户")]
        let replacement = [Account(id: UUID(), provider: .moonshot, label: "替换账户")]
        let store = FileSnapshotStore(directoryURL: directory)
        try store.saveAccounts(original)

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: directory.path
        )
        var writeFailed = false
        do {
            try store.saveAccounts(replacement)
        } catch {
            writeFailed = true
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )

        #expect(writeFailed)
        #expect(store.loadAccounts() == original)
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuotrackTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
