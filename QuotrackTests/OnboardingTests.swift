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
    func openingFromAProviderCardPreselectsThatProvider() throws {
        let manager = AccountManager(
            store: InMemorySnapshotStore(),
            credentialStore: InMemoryCredentialStore()
        )
        let tester = RecordingConnectionTester(
            balanceResult: .success(makeOnboardingSnapshot())
        )

        let deepSeek = OnboardingModel(
            accountManager: manager,
            connectionTester: tester,
            initialProvider: .deepSeek
        )
        #expect(deepSeek.selectedProvider == .deepSeek)
        #expect(deepSeek.selectedKind == .balance)
        #expect(deepSeek.step == .details)

        let moonshot = OnboardingModel(
            accountManager: manager,
            connectionTester: tester,
            initialProvider: .moonshot
        )
        #expect(moonshot.selectedProvider == .moonshot)
        #expect(moonshot.selectedKind == .balance)
        #expect(moonshot.step == .region)

        moonshot.back()
        #expect(moonshot.step == .provider)
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
    func onboardingSavesAKimiCodeSubscriptionAccount() async throws {
        let quota = QuotaSnapshot(
            accountID: UUID(),
            limit: 100,
            remaining: 60,
            fetchedAt: Date()
        )
        let context = makeContext(
            accountResult: .success(AccountSnapshot.quota(quota))
        )
        context.model.selectedProvider = .moonshot
        context.model.advance()
        context.model.advance()
        context.model.selectedKind = .subscription
        context.model.warningThresholdText = "10"
        context.model.criticalThresholdText = "5"
        context.model.label = "Kimi Code"
        context.model.credential = "sk-kimi"

        await context.model.submit()

        let account = try #require(context.model.completedAccount)
        #expect(account.kind == .subscription)
        #expect(account.warningThreshold == 10)
        #expect(account.criticalThreshold == 5)
        #expect(account.currency == nil)
        #expect(context.manager.accounts == [account])
    }

    @Test
    func onboardingSavesTheEnteredThresholds() async throws {
        let context = makeContext()
        context.model.selectedProvider = .deepSeek
        context.model.advance()
        context.model.label = "个人账户"
        context.model.credential = "sk-deepseek"
        context.model.warningThresholdText = "50"
        context.model.criticalThresholdText = "20"

        await context.model.submit()

        let account = try #require(context.model.completedAccount)
        #expect(account.warningThreshold == Decimal(string: "50"))
        #expect(account.criticalThreshold == Decimal(string: "20"))
        #expect(account.currency == .cny)
        #expect(context.manager.accounts == [account])
    }

    @Test
    func invalidOnboardingThresholdsStayOnDetailsAndDoNotTestTheCredential() async throws {
        let context = makeContext()
        context.model.selectedProvider = .deepSeek
        context.model.advance()
        context.model.label = "个人账户"
        context.model.credential = "sk-deepseek"
        context.model.warningThresholdText = "0"

        await context.model.submit()

        #expect(context.model.step == .details)
        #expect(context.model.errorMessage == UIStrings.invalidThreshold)
        #expect(context.tester.requests.isEmpty)
        #expect(context.manager.accounts.isEmpty)
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
        #expect(account.warningThreshold == nil)
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
        context.model.selectedProvider = .deepSeek
        context.model.advance()
        context.model.label = "  国内账户  "
        context.model.credential = "sk-deepseek"

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
    accountResult: Result<AccountSnapshot, BalanceProviderError>
) -> OnboardingContext {
    let store = InMemorySnapshotStore()
    let credentials = InMemoryCredentialStore()
    let manager = AccountManager(store: store, credentialStore: credentials)
    let tester = RecordingConnectionTester(result: accountResult)
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
