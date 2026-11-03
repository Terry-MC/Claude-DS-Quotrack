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
    func warningAndCriticalThresholdsCanBeSetAndPersist() throws {
        let store = InMemorySnapshotStore()
        let manager = makeManager(store: store)
        let account = try manager.addAccount(
            provider: .deepSeek,
            label: "个人账户",
            credential: "sk-deepseek"
        )

        try manager.updateThresholds(
            accountID: account.id,
            thresholds: AccountThresholds(
                warning: Decimal(string: "50"),
                critical: Decimal(string: "20")
            )
        )

        let updated = try #require(manager.accounts.first)
        #expect(updated.id == account.id)
        #expect(updated.kind == .balance)
        #expect(updated.warningThreshold == Decimal(string: "50"))
        #expect(updated.criticalThreshold == Decimal(string: "20"))
        #expect(store.loadAccounts() == [updated])
    }

    @Test
    func editingTheLabelPreservesKindAndBothThresholds() throws {
        let store = InMemorySnapshotStore()
        let manager = makeManager(store: store)
        let draft = AccountDraft(
            provider: .moonshot,
            label: "Kimi Code",
            credential: "sk-kimi",
            kind: .subscription
        )
        let account = try manager.addAccount(draft)
        try manager.updateThresholds(
            accountID: account.id,
            thresholds: AccountThresholds(warning: 20, critical: 10)
        )

        try manager.updateLabel(accountID: account.id, label: "Kimi Code 2")

        let updated = try #require(manager.accounts.first)
        #expect(updated.kind == .subscription)
        #expect(updated.warningThreshold == 20)
        #expect(updated.criticalThreshold == 10)
        #expect(store.loadAccounts() == [updated])
    }

    @Test
    func nonPositiveThresholdsAreRejectedByTheTwoLevelPath() throws {
        let store = InMemorySnapshotStore()
        let manager = makeManager(store: store)
        let account = try manager.addAccount(
            provider: .deepSeek,
            label: "个人账户",
            credential: "sk-deepseek"
        )

        #expect(throws: AccountManagerError.invalidThreshold) {
            try manager.updateThresholds(
                accountID: account.id,
                thresholds: AccountThresholds(warning: 0)
            )
        }
        #expect(throws: AccountManagerError.invalidThreshold) {
            try manager.updateThresholds(
                accountID: account.id,
                thresholds: AccountThresholds(critical: -1)
            )
        }

        #expect(manager.accounts.first?.warningThreshold == nil)
        #expect(manager.accounts.first?.criticalThreshold == nil)
        #expect(store.loadAccounts().first?.warningThreshold == nil)
        #expect(store.loadAccounts().first?.criticalThreshold == nil)
    }

    @Test
    func aCriticalThresholdAtOrAboveTheWarningThresholdIsRejected() throws {
        let store = InMemorySnapshotStore()
        let manager = makeManager(store: store)
        let account = try manager.addAccount(
            provider: .deepSeek,
            label: "个人账户",
            credential: "sk-deepseek"
        )

        #expect(throws: AccountManagerError.invalidThreshold) {
            try manager.updateThresholds(
                accountID: account.id,
                thresholds: AccountThresholds(warning: 10, critical: 10)
            )
        }
        #expect(throws: AccountManagerError.invalidThreshold) {
            try manager.updateThresholds(
                accountID: account.id,
                thresholds: AccountThresholds(warning: 10, critical: 20)
            )
        }

        #expect(manager.accounts.first?.warningThreshold == nil)
        #expect(manager.accounts.first?.criticalThreshold == nil)
        #expect(store.loadAccounts().first?.warningThreshold == nil)
        #expect(store.loadAccounts().first?.criticalThreshold == nil)
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
