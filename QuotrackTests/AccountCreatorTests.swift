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
    func aSuccessfulConnectionTestSavesTheAccountAndThreshold() async throws {
        let store = InMemorySnapshotStore()
        let credentials = InMemoryCredentialStore()
        let manager = AccountManager(store: store, credentialStore: credentials)
        let tester = RecordingConnectionTester(result: .success(makeSnapshot()))
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
