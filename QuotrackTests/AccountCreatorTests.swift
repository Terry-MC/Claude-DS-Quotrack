import Foundation
import Testing

/// Settings uses the same test-before-save path as onboarding. These tests
/// exercise that path without a view or a network.
@MainActor
struct AccountCreatorTests {
    @Test
    func aFailedConnectionTestReportsTheErrorAndSavesNothing() async throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)
        let tester = RecordingConnectionTester(
            result: .failure(BalanceProviderError.authentication)
        )
        let creator = AccountCreator(manager: manager, connectionTester: tester)
        let draft = AccountDraft(
            provider: .openRouter,
            label: "管理账户",
            credential: "sk-or"
        )

        await #expect(throws: BalanceProviderError.authentication) {
            try await creator.create(draft)
        }

        #expect(manager.accounts.isEmpty)
        #expect(store.loadAccounts().isEmpty)
        #expect(credentials.saveCallCount == 0)
        #expect(tester.requests.map(\.draft) == [draft])
    }

    @Test
    func invalidThresholdsAreRejectedBeforeTheConnectionTestOrSave() async throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)
        let tester = RecordingConnectionTester(balanceResult: .success(makeSnapshot()))
        let creator = AccountCreator(manager: manager, connectionTester: tester)
        let draft = AccountDraft(
            provider: .moonshot,
            label: "Kimi Code",
            credential: "sk-kimi",
            kind: .subscription
        )

        await #expect(throws: AccountManagerError.invalidThreshold) {
            try await creator.create(
                draft,
                thresholds: AccountThresholds(warning: 150)
            )
        }

        #expect(manager.accounts.isEmpty)
        #expect(store.loadAccounts().isEmpty)
        #expect(credentials.saveCallCount == 0)
        #expect(tester.requests.isEmpty)
    }

    @Test
    func aSuccessfulConnectionTestSavesTheAccountAndThreshold() async throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)
        let tester = RecordingConnectionTester(balanceResult: .success(makeSnapshot()))
        let creator = AccountCreator(manager: manager, connectionTester: tester)
        let draft = AccountDraft(
            provider: .moonshot,
            region: .international,
            label: "Kimi 国际",
            credential: "sk-moonshot"
        )

        let account = try await creator.create(
            draft,
            lowBalanceThreshold: Decimal(string: "5.00")
        )

        #expect(account.provider == .moonshot)
        #expect(account.region == .international)
        #expect(account.label == "Kimi 国际")
        #expect(account.lowBalanceThreshold == Decimal(string: "5.00"))
        #expect(manager.accounts == [account])
        #expect(tester.requests.map(\.draft) == [draft])
        #expect(try credentials.credential(for: account.id) == "sk-moonshot")
    }

    @Test
    func aSuccessfulConnectionTestSavesBothThresholds() async throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)
        let tester = RecordingConnectionTester(balanceResult: .success(makeSnapshot()))
        let creator = AccountCreator(manager: manager, connectionTester: tester)
        let draft = AccountDraft(
            provider: .deepSeek,
            label: "个人账户",
            credential: "sk-deepseek"
        )
        let thresholds = AccountThresholds(
            warning: Decimal(string: "50"),
            critical: Decimal(string: "20")
        )

        let account = try await creator.create(draft, thresholds: thresholds)

        #expect(account.warningThreshold == Decimal(string: "50"))
        #expect(account.criticalThreshold == Decimal(string: "20"))
        #expect(manager.accounts == [account])
        #expect(store.loadAccounts() == [account])
        #expect(tester.requests.map(\.draft) == [draft])
    }

    @Test
    func openRouterWarnsAboutTheManagementKeyBeforeSave() {
        #expect(
            AccountFormPresentation.credentialWarning(for: .openRouter)
                == UIStrings.openRouterManagementKeyWarning
        )
        #expect(AccountFormPresentation.credentialWarning(for: .deepSeek) == nil)
        #expect(AccountFormPresentation.credentialWarning(for: .moonshot) == nil)
        #expect(AccountFormPresentation.credentialWarning(for: .siliconFlow) == nil)
    }
}

private func makeSnapshot() -> BalanceSnapshot {
    BalanceSnapshot(
        accountID: UUID(),
        balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
        fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
        isAvailable: true
    )
}
