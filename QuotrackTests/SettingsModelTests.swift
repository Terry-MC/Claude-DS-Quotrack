import Foundation
import ServiceManagement
import Testing

@MainActor
struct SettingsModelTests {
    @Test
    func launchAtLoginDefaultsOffWhenTheSystemHasNoRegistration() {
        let model = makeModel(loginStatus: .notRegistered)

        #expect(model.launchAtLoginStatus == .notRegistered)
        #expect(model.isLaunchAtLoginEnabled == false)
        #expect(model.requiresApproval == false)
    }

    @Test
    func enablingLaunchAtLoginRegistersTheLoginItem() {
        let loginItems = FakeLoginItemService(status: .notRegistered)
        loginItems.statusAfterRegister = .enabled
        let model = makeModel(loginItems: loginItems)

        model.setLaunchAtLogin(true)

        #expect(loginItems.registerCallCount == 1)
        #expect(loginItems.unregisterCallCount == 0)
        #expect(model.launchAtLoginStatus == .enabled)
        #expect(model.isLaunchAtLoginEnabled)
    }

    @Test
    func disablingLaunchAtLoginUnregistersTheLoginItem() {
        let loginItems = FakeLoginItemService(status: .enabled)
        loginItems.statusAfterUnregister = .notRegistered
        let model = makeModel(loginItems: loginItems)

        model.setLaunchAtLogin(false)

        #expect(loginItems.unregisterCallCount == 1)
        #expect(loginItems.registerCallCount == 0)
        #expect(model.isLaunchAtLoginEnabled == false)
    }

    @Test
    func registrationThatRequiresApprovalIsSurfacedAndOpensSystemSettings() {
        let loginItems = FakeLoginItemService(status: .notRegistered)
        loginItems.statusAfterRegister = .requiresApproval
        let model = makeModel(loginItems: loginItems)

        model.setLaunchAtLogin(true)

        #expect(model.isLaunchAtLoginEnabled == false)
        #expect(model.requiresApproval)
        #expect(loginItems.openSystemSettingsCallCount == 1)
    }

    @Test
    func refreshingReadsTheSystemStatusAsTheSourceOfTruth() {
        let loginItems = FakeLoginItemService(status: .notRegistered)
        let model = makeModel(loginItems: loginItems)
        #expect(model.isLaunchAtLoginEnabled == false)

        loginItems.status = .enabled
        model.refreshLoginItemStatus()

        #expect(model.isLaunchAtLoginEnabled)
    }

    @Test
    func aRegisterFailureIsReportedWithoutClaimingSuccess() {
        let loginItems = FakeLoginItemService(status: .notRegistered)
        loginItems.registerError = FakeLoginItemFailure.denied
        let model = makeModel(loginItems: loginItems)

        model.setLaunchAtLogin(true)

        #expect(model.isLaunchAtLoginEnabled == false)
        #expect(model.loginItemErrorMessage != nil)
    }

    @Test
    func changingThePollingIntervalPersistsItAndNotifiesTheMonitor() {
        let store = InMemorySettingsStore(settings: AppSettings(pollingIntervalMinutes: 5))
        let model = makeModel(store: store)
        var observedInterval: TimeInterval?
        model.onPollingIntervalChanged = { observedInterval = $0 }

        model.setPollingInterval(minutes: 17)

        #expect(model.pollingIntervalMinutes == 17)
        #expect(store.loadSettings().pollingIntervalMinutes == 17)
        #expect(store.saveCallCount == 1)
        let expectedInterval: TimeInterval = 1_020
        #expect(observedInterval == expectedInterval)
    }

    @Test
    func anOutOfRangeIntervalIsClampedBeforePersisting() {
        let store = InMemorySettingsStore()
        let model = makeModel(store: store)

        model.setPollingInterval(minutes: 0)

        #expect(model.pollingIntervalMinutes == 1)
        #expect(store.loadSettings().pollingIntervalMinutes == 1)
    }

    @Test
    func settingTheSameIntervalDoesNotWriteAgain() {
        let store = InMemorySettingsStore(settings: AppSettings(pollingIntervalMinutes: 5))
        let model = makeModel(store: store)

        model.setPollingInterval(minutes: 5)

        #expect(store.saveCallCount == 0)
    }

    @Test
    func alreadyRegisteredIsAnIdempotentRegisterSuccess() {
        let error = NSError(
            domain: SMAppServiceErrorDomain,
            code: kSMErrorAlreadyRegistered
        )

        #expect(SMAppServiceLoginItemService.isIdempotentRegisterError(error))
        #expect(!SMAppServiceLoginItemService.isIdempotentRegisterError(
            NSError(domain: SMAppServiceErrorDomain, code: kSMErrorInternalFailure)
        ))
        #expect(!SMAppServiceLoginItemService.isIdempotentRegisterError(
            NSError(domain: "OtherDomain", code: kSMErrorAlreadyRegistered)
        ))
    }

    @Test
    func jobNotFoundIsAnIdempotentUnregisterSuccess() {
        let error = NSError(
            domain: SMAppServiceErrorDomain,
            code: kSMErrorJobNotFound
        )

        #expect(SMAppServiceLoginItemService.isIdempotentUnregisterError(error))
        #expect(!SMAppServiceLoginItemService.isIdempotentUnregisterError(
            NSError(domain: SMAppServiceErrorDomain, code: kSMErrorInternalFailure)
        ))
    }
}

@MainActor
private func makeModel(
    store: InMemorySettingsStore = InMemorySettingsStore(),
    loginItems: FakeLoginItemService = FakeLoginItemService(),
    loginStatus: LoginItemStatus? = nil
) -> SettingsModel {
    if let loginStatus {
        loginItems.status = loginStatus
    }
    return SettingsModel(store: store, loginItemService: loginItems)
}

private enum FakeLoginItemFailure: Error {
    case denied
}
