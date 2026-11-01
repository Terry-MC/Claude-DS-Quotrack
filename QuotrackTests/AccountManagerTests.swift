import Foundation
import Testing

@MainActor
struct AccountManagerTests {
    @Test
    func addingAnAccountShowsItInTheAccountListAndPersistsItsMetadata() throws {
        let store = InMemorySnapshotStore()
        let manager = AccountManager(
            store: store,
            credentialStore: InMemoryCredentialStore()
        )

        let account = try manager.addAccount(
            provider: .deepSeek,
            label: "个人账户",
            credential: "sk-deepseek"
        )

        #expect(manager.accounts == [account])
        #expect(store.loadAccounts() == [account])
        #expect(account.provider == .deepSeek)
        #expect(account.label == "个人账户")
    }

    @Test
    func addingAnAccountStoresTheCredentialOnlyInTheCredentialStore() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileSnapshotStore(directoryURL: directory)
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)

        let account = try manager.addAccount(
            provider: .deepSeek,
            label: "个人账户",
            credential: "sk-very-secret"
        )

        let storedCredential = try credentials.credential(for: account.id)
        #expect(storedCredential == "sk-very-secret")
        let metadata = try String(
            contentsOf: directory.appendingPathComponent("accounts.json"),
            encoding: .utf8
        )
        #expect(!metadata.contains("sk-very-secret"))
    }

    @Test
    func addingARegionCapableAccountKeepsTheChosenRegion() throws {
        let manager = AccountManager(
            store: InMemorySnapshotStore(),
            credentialStore: InMemoryCredentialStore()
        )

        let account = try manager.addAccount(
            provider: .moonshot,
            region: .international,
            label: "Kimi 国际",
            credential: "sk-moonshot"
        )

        #expect(account.region == .international)
    }

    @Test
    func addingARegionCapableAccountWithoutAChoiceDefaultsToDomestic() throws {
        let manager = AccountManager(
            store: InMemorySnapshotStore(),
            credentialStore: InMemoryCredentialStore()
        )

        let account = try manager.addAccount(
            provider: .siliconFlow,
            label: "SiliconFlow",
            credential: "sk-siliconflow"
        )

        #expect(account.region == .domestic)
    }

    @Test
    func addingAnAccountForAProviderWithoutRegionsDropsTheRegion() throws {
        let manager = AccountManager(
            store: InMemorySnapshotStore(),
            credentialStore: InMemoryCredentialStore()
        )

        let account = try manager.addAccount(
            provider: .deepSeek,
            region: .international,
            label: "DeepSeek",
            credential: "sk-deepseek"
        )

        #expect(account.region == nil)
    }

    @Test
    func editingTheLabelKeepsTheAccountIdentityAndCredential() throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)
        let account = try manager.addAccount(
            provider: .moonshot,
            region: .domestic,
            label: "旧标签",
            credential: "sk-original"
        )

        try manager.updateLabel(accountID: account.id, label: "新标签")

        let updated = try #require(manager.accounts.first)
        #expect(updated.id == account.id)
        #expect(updated.provider == account.provider)
        #expect(updated.region == account.region)
        #expect(updated.label == "新标签")
        #expect(manager.accounts.count == 1)
        #expect(store.loadAccounts() == [updated])
        let storedCredential = try credentials.credential(for: account.id)
        #expect(storedCredential == "sk-original")
    }

    @Test
    func replacingTheCredentialChangesOnlyTheStoredCredential() throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)
        let account = try manager.addAccount(
            provider: .openRouter,
            label: "管理账户",
            credential: "sk-old"
        )
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "12.00")!, currency: .usd),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: true
        )
        try store.saveSnapshot(snapshot)

        try manager.replaceCredential(accountID: account.id, credential: "sk-new")

        #expect(manager.accounts == [account])
        #expect(store.loadAccounts() == [account])
        let storedCredential = try credentials.credential(for: account.id)
        #expect(storedCredential == "sk-new")
        #expect(store.loadSnapshots() == [account.id: snapshot])
    }

    @Test
    func deletingAnAccountRemovesItsCredentialMetadataAndSnapshot() throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)
        let kept = try manager.addAccount(
            provider: .deepSeek,
            label: "保留账户",
            credential: "sk-keep"
        )
        let deleted = try manager.addAccount(
            provider: .moonshot,
            region: .international,
            label: "删除账户",
            credential: "sk-delete"
        )
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
        try store.saveSnapshot(keptSnapshot)
        try store.saveSnapshot(deletedSnapshot)

        try manager.deleteAccount(id: deleted.id)

        #expect(manager.accounts == [kept])
        #expect(store.loadAccounts() == [kept])
        let deletedCredential = try credentials.credential(for: deleted.id)
        #expect(deletedCredential == nil)
        let keptCredential = try credentials.credential(for: kept.id)
        #expect(keptCredential == "sk-keep")
        #expect(store.loadSnapshots() == [kept.id: keptSnapshot])
    }

    @Test
    func addingAnAccountWithoutALabelIsRejected() throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)

        #expect(throws: AccountManagerError.missingLabel) {
            try manager.addAccount(
                provider: .deepSeek,
                label: "   ",
                credential: "sk-deepseek"
            )
        }

        #expect(manager.accounts.isEmpty)
        #expect(store.loadAccounts().isEmpty)
        #expect(credentials.saveCallCount == 0)
    }

    @Test
    func addingAnAccountWithoutACredentialIsRejected() throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)

        #expect(throws: AccountManagerError.missingCredential) {
            try manager.addAccount(
                provider: .deepSeek,
                label: "个人账户",
                credential: ""
            )
        }

        #expect(manager.accounts.isEmpty)
        #expect(store.loadAccounts().isEmpty)
        #expect(credentials.saveCallCount == 0)
    }

    @Test
    func renamingAnAccountToABlankLabelIsRejected() throws {
        let store = InMemorySnapshotStore()
        let manager = AccountManager(
            store: store,
            credentialStore: InMemoryCredentialStore()
        )
        let account = try manager.addAccount(
            provider: .deepSeek,
            label: "个人账户",
            credential: "sk-deepseek"
        )

        #expect(throws: AccountManagerError.missingLabel) {
            try manager.updateLabel(accountID: account.id, label: " ")
        }

        #expect(manager.accounts == [account])
        #expect(store.loadAccounts() == [account])
    }

    @Test
    func replacingACredentialWithAnEmptyValueIsRejected() throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)
        let account = try manager.addAccount(
            provider: .deepSeek,
            label: "个人账户",
            credential: "sk-original"
        )

        #expect(throws: AccountManagerError.missingCredential) {
            try manager.replaceCredential(accountID: account.id, credential: "")
        }

        let storedCredential = try credentials.credential(for: account.id)
        #expect(storedCredential == "sk-original")
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuotrackAccountTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
