import Foundation
import Testing

@MainActor
struct OnboardingTests {
    @Test
    func onboardingStartsAtProviderSelection() throws {
        let context = makeContext()

        #expect(context.model.step == .provider)
        #expect(context.model.completedAccount == nil)
        #expect(context.model.errorMessage == nil)
    }

    @Test
    func selectingOpenRouterWarnsAboutTheManagementKeyBeforeSaving() throws {
        let context = makeContext()

        context.model.selectedProvider = .openRouter

        #expect(context.model.credentialWarning == UIStrings.openRouterManagementKeyWarning)
        context.model.selectedProvider = .deepSeek
        #expect(context.model.credentialWarning == nil)
    }

    @Test
    func aProviderWithoutRegionsGoesStraightToAccountDetails() throws {
        let context = makeContext()

        context.model.selectedProvider = .deepSeek
        context.model.advance()

        #expect(context.model.step == .details)
        context.model.back()
        #expect(context.model.step == .provider)
    }

    @Test
    func aRegionCapableProviderAsksForTheRegionBeforeAccountDetails() throws {
        let context = makeContext()

        context.model.selectedProvider = .moonshot
        context.model.advance()
        #expect(context.model.step == .region)

        context.model.selectedRegion = .international
        context.model.advance()
        #expect(context.model.step == .details)

        context.model.back()
        #expect(context.model.step == .region)
        #expect(context.model.selectedRegion == .international)
        context.model.back()
        #expect(context.model.step == .provider)
    }

    @Test
    func onSubmitWithoutALabelOrCredentialTheTesterIsNotCalled() async throws {
        let context = makeContext()
        context.model.selectedProvider = .deepSeek
        context.model.advance()
        context.model.label = "  "
        context.model.credential = ""

        await context.model.submit()

        #expect(context.model.step == .details)
        #expect(context.model.errorMessage != nil)
        #expect(context.tester.requests.isEmpty)
        #expect(context.manager.accounts.isEmpty)
    }

    @Test
    func aFailedConnectionTestShowsTheErrorAndSavesNothing() async throws {
        let context = makeContext(
            testerResult: .failure(BalanceProviderError.authentication)
        )
        context.model.selectedProvider = .openRouter
        context.model.advance()
        context.model.label = "管理账户"
        context.model.credential = "sk-or"

        await context.model.submit()

        #expect(context.model.step == .details)
        #expect(context.model.errorMessage == UIStrings.authenticationError)
        #expect(context.model.completedAccount == nil)
        #expect(context.manager.accounts.isEmpty)
        #expect(context.store.loadAccounts().isEmpty)
        #expect(context.credentials.saveCallCount == 0)
        #expect(context.tester.requests == [
            RecordingConnectionTester.Request(
                draft: AccountDraft(
                    provider: .openRouter,
                    label: "管理账户",
                    credential: "sk-or"
                )
            )
        ])
    }

    @Test
    func aMoonshotAuthenticationFailureSuggestsCheckingTheRegion() async throws {
        let context = makeContext(
            testerResult: .failure(BalanceProviderError.authentication)
        )
        context.model.selectedProvider = .moonshot
        context.model.advance()
        context.model.selectedRegion = .international
        context.model.advance()
        context.model.label = "Kimi 国际"
        context.model.credential = "sk-wrong-region"

        await context.model.submit()

        #expect(context.model.step == .details)
        #expect(context.model.errorMessage == UIStrings.regionAuthenticationError)
        #expect(context.model.errorMessage?.contains("区域") == true)
        #expect(context.manager.accounts.isEmpty)
        #expect(context.credentials.saveCallCount == 0)
    }

    @Test
    func aSuccessfulConnectionTestSavesTheAccountAndCompletesOnboarding() async throws {
        let context = makeContext()
        context.model.selectedProvider = .moonshot
        context.model.advance()
        context.model.selectedRegion = .international
        context.model.advance()
        context.model.label = "Kimi 国际"
        context.model.credential = "sk-moonshot"

        await context.model.submit()

        #expect(context.model.step == .completed)
        #expect(context.model.errorMessage == nil)
        let account = try #require(context.model.completedAccount)
        #expect(account.provider == .moonshot)
        #expect(account.region == .international)
        #expect(account.label == "Kimi 国际")
        #expect(account.lowBalanceThreshold == nil)
        #expect(context.manager.accounts == [account])
        #expect(context.store.loadAccounts() == [account])
        let storedCredential = try context.credentials.credential(for: account.id)
        #expect(storedCredential == "sk-moonshot")
        #expect(context.tester.requests == [
            RecordingConnectionTester.Request(
                draft: AccountDraft(
                    provider: .moonshot,
                    region: .international,
                    label: "Kimi 国际",
                    credential: "sk-moonshot"
                )
            )
        ])
    }

    @Test
    func aRetryAfterAFailedConnectionTestCanSucceed() async throws {
        let context = makeContext(testerResults: [
            .failure(BalanceProviderError.network),
            .success(makeOnboardingSnapshot()),
        ])
        context.model.selectedProvider = .deepSeek
        context.model.advance()
        context.model.label = "个人账户"
        context.model.credential = "sk-deepseek"

        await context.model.submit()
        #expect(context.model.step == .details)
        #expect(context.model.errorMessage == UIStrings.networkError)
        #expect(context.manager.accounts.isEmpty)

        await context.model.submit()

        #expect(context.model.step == .completed)
        #expect(context.model.errorMessage == nil)
        #expect(context.manager.accounts.count == 1)
        #expect(context.tester.requests.count == 2)
    }

    @Test
    func accountDetailsAreTrimmedBeforeSaving() async throws {
        let context = makeContext()
        context.model.selectedProvider = .siliconFlow
        context.model.advance()
        context.model.selectedRegion = .domestic
        context.model.advance()
        context.model.label = "  国内账户  "
        context.model.credential = "sk-silicon"

        await context.model.submit()

        let account = try #require(context.model.completedAccount)
        #expect(account.label == "国内账户")
    }
}

@MainActor
private struct OnboardingContext {
    let model: OnboardingModel
    let manager: AccountManager
    let store: InMemorySnapshotStore
    let credentials: InMemoryCredentialStore
    let tester: RecordingConnectionTester
}

@MainActor
private func makeContext(
    testerResult: Result<BalanceSnapshot, BalanceProviderError> = .success(makeOnboardingSnapshot())
) -> OnboardingContext {
    let store = InMemorySnapshotStore()
    let credentials = InMemoryCredentialStore()
    let manager = AccountManager(store: store, credentialStore: credentials)
    let tester = RecordingConnectionTester(balanceResult: testerResult)
    let model = OnboardingModel(accountManager: manager, connectionTester: tester)
    return OnboardingContext(
        model: model,
        manager: manager,
        store: store,
        credentials: credentials,
        tester: tester
    )
}

@MainActor
private func makeContext(
    testerResults: [Result<BalanceSnapshot, BalanceProviderError>]
) -> OnboardingContext {
    let store = InMemorySnapshotStore()
    let credentials = InMemoryCredentialStore()
    let manager = AccountManager(store: store, credentialStore: credentials)
    let tester = RecordingConnectionTester(balanceResults: testerResults)
    let model = OnboardingModel(accountManager: manager, connectionTester: tester)
    return OnboardingContext(
        model: model,
        manager: manager,
        store: store,
        credentials: credentials,
        tester: tester
    )
}

private func makeOnboardingSnapshot() -> BalanceSnapshot {
    BalanceSnapshot(
        accountID: UUID(),
        balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
        fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
        isAvailable: true
    )
}
