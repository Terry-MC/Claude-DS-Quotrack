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
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuotrackAccountTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
