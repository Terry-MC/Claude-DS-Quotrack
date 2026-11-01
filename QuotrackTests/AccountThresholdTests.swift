import Foundation
import Testing

@MainActor
struct AccountThresholdTests {
    @Test
    func newAccountsHaveLowBalanceThresholdDisabledByDefault() throws {
        let store = InMemorySnapshotStore()
        let manager = makeManager(store: store)

        let account = try manager.addAccount(
            provider: .deepSeek,
            label: "个人账户",
            credential: "sk-deepseek"
        )

        #expect(account.lowBalanceThreshold == nil)
        #expect(store.loadAccounts().first?.lowBalanceThreshold == nil)
    }

    @Test
    func aLowBalanceThresholdCanBeEnabledAndPersists() throws {
        let store = InMemorySnapshotStore()
        let manager = makeManager(store: store)
        let account = try manager.addAccount(
            provider: .moonshot,
            label: "Kimi",
            credential: "sk-moonshot"
        )

        try manager.updateLowBalanceThreshold(
            accountID: account.id,
            threshold: Decimal(string: "10.50")
        )

        let updated = try #require(manager.accounts.first)
        #expect(updated.lowBalanceThreshold == Decimal(string: "10.50"))
        #expect(updated.id == account.id)
        #expect(store.loadAccounts() == [updated])
    }

    @Test
    func clearingTheThresholdTurnsTheWarningOff() throws {
        let store = InMemorySnapshotStore()
        let manager = makeManager(store: store)
        let account = try manager.addAccount(
            provider: .siliconFlow,
            label: "SiliconFlow",
            credential: "sk-siliconflow"
        )
        try manager.updateLowBalanceThreshold(
            accountID: account.id,
            threshold: Decimal(string: "5")
        )

        try manager.updateLowBalanceThreshold(accountID: account.id, threshold: nil)

        #expect(manager.accounts.first?.lowBalanceThreshold == nil)
        #expect(store.loadAccounts().first?.lowBalanceThreshold == nil)
    }

    @Test
    func editingTheLabelPreservesTheLowBalanceThreshold() throws {
        let manager = makeManager(store: InMemorySnapshotStore())
        let account = try manager.addAccount(
            provider: .deepSeek,
            label: "旧标签",
            credential: "sk-deepseek"
        )
        try manager.updateLowBalanceThreshold(
            accountID: account.id,
            threshold: Decimal(string: "8")
        )

        try manager.updateLabel(accountID: account.id, label: "新标签")

        let updated = try #require(manager.accounts.first)
        #expect(updated.label == "新标签")
        #expect(updated.lowBalanceThreshold == Decimal(string: "8"))
    }

    @Test
    func aZeroOrNegativeThresholdIsRejected() throws {
        let store = InMemorySnapshotStore()
        let manager = makeManager(store: store)
        let account = try manager.addAccount(
            provider: .openRouter,
            label: "管理账户",
            credential: "sk-or"
        )

        #expect(throws: AccountManagerError.invalidThreshold) {
            try manager.updateLowBalanceThreshold(accountID: account.id, threshold: 0)
        }
        #expect(throws: AccountManagerError.invalidThreshold) {
            try manager.updateLowBalanceThreshold(accountID: account.id, threshold: -1)
        }
        #expect(manager.accounts.first?.lowBalanceThreshold == nil)
        #expect(store.loadAccounts().first?.lowBalanceThreshold == nil)
    }

    @Test
    func accountMetadataWithoutAThresholdDecodesWithTheWarningOff() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuotrackThresholdTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID()
        let legacyJSON = """
        [{"id":"\(accountID.uuidString)","provider":"deepSeek","label":"个人账户"}]
        """
        try Data(legacyJSON.utf8).write(
            to: directory.appendingPathComponent("accounts.json")
        )

        let accounts = FileSnapshotStore(directoryURL: directory).loadAccounts()

        let account = try #require(accounts.first)
        #expect(account.id == accountID)
        #expect(account.lowBalanceThreshold == nil)
    }
}

@MainActor
private func makeManager(store: InMemorySnapshotStore) -> AccountManager {
    AccountManager(store: store, credentialStore: InMemoryCredentialStore())
}
