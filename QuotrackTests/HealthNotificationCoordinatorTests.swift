import Foundation
import Testing

/// The coordinator is the boundary between pure detection and delivery. Tests
/// inject permission and delivery fakes, so no system notification is scheduled
/// and no UI appears.
@MainActor
struct HealthNotificationCoordinatorTests {
    @Test
    func authorizedPermissionUsesASystemNotificationAndClickOpensThePanel() async throws {
        let account = HealthTestSupport.balanceAccount()
        let authorization = FakeAuthorization(
            status: .authorized,
            requestResult: .authorized
        )
        let deliverer = RecordingNotificationDeliverer()
        let toast = RecordingToastPresenter()
        var openedAccountID: Account.ID?
        let coordinator = makeCoordinator(
            authorization: authorization,
            deliverer: deliverer,
            toast: toast,
            openAccount: { openedAccountID = $0 }
        )

        coordinator.pollDidComplete(rows: [row(account, balance: 20)])
        await coordinator.deliveryTask?.value
        coordinator.pollDidComplete(rows: [row(account, balance: 8)])
        let delivery = coordinator.deliveryTask
        #expect(delivery != nil)
        await delivery?.value

        #expect(deliverer.contents.count == 1)
        #expect(toast.contents.isEmpty)
        #expect(deliverer.contents.first?.affectedAccountIDs == [account.id])

        deliverer.openActions.first?()
        #expect(openedAccountID == account.id)
    }

    @Test
    func deniedPermissionFallsBackToTheInAppToast() async {
        let account = HealthTestSupport.balanceAccount()
        let authorization = FakeAuthorization(
            status: .denied,
            requestResult: .denied
        )
        let deliverer = RecordingNotificationDeliverer()
        let toast = RecordingToastPresenter()
        var openedAccountID: Account.ID?
        let coordinator = makeCoordinator(
            authorization: authorization,
            deliverer: deliverer,
            toast: toast,
            openAccount: { openedAccountID = $0 }
        )
        coordinator.pollDidComplete(rows: [row(account, balance: 20)])
        await coordinator.deliveryTask?.value
        coordinator.pollDidComplete(rows: [row(account, balance: 8)])
        await coordinator.deliveryTask?.value

        #expect(deliverer.contents.isEmpty)
        #expect(toast.contents.count == 1)
        #expect(authorization.requestCallCount == 0)

        toast.openActions.first?()
        #expect(openedAccountID == account.id)
    }

    @Test
    func notDeterminedPermissionIsRequestedOnceAndUsesTheResult() async {
        let account = HealthTestSupport.balanceAccount()
        let authorization = FakeAuthorization(
            status: .notDetermined,
            requestResult: .authorized
        )
        let deliverer = RecordingNotificationDeliverer()
        let toast = RecordingToastPresenter()
        let coordinator = makeCoordinator(
            authorization: authorization,
            deliverer: deliverer,
            toast: toast
        )
        coordinator.pollDidComplete(rows: [row(account, balance: 20)])
        await coordinator.deliveryTask?.value
        coordinator.pollDidComplete(rows: [row(account, balance: 8)])
        await coordinator.deliveryTask?.value

        #expect(authorization.permissionCallCount == 1)
        #expect(authorization.requestCallCount == 1)
        #expect(deliverer.contents.count == 1)
        #expect(toast.contents.isEmpty)
    }

    @Test
    func aDeniedPermissionRequestFallsBackToTheToast() async {
        let account = HealthTestSupport.balanceAccount()
        let authorization = FakeAuthorization(
            status: .notDetermined,
            requestResult: .denied
        )
        let deliverer = RecordingNotificationDeliverer()
        let toast = RecordingToastPresenter()
        let coordinator = makeCoordinator(
            authorization: authorization,
            deliverer: deliverer,
            toast: toast
        )
        coordinator.pollDidComplete(rows: [row(account, balance: 20)])
        await coordinator.deliveryTask?.value
        coordinator.pollDidComplete(rows: [row(account, balance: 8)])
        await coordinator.deliveryTask?.value

        #expect(authorization.requestCallCount == 1)
        #expect(deliverer.contents.isEmpty)
        #expect(toast.contents.count == 1)
    }

    @Test
    func multipleTransitionsInOnePollProduceOneDeliveryAndFocusTheFirstAccount() async throws {
        let first = HealthTestSupport.balanceAccount(label: "第一个")
        let second = HealthTestSupport.quotaAccount(label: "第二个")
        let deliverer = RecordingNotificationDeliverer()
        let toast = RecordingToastPresenter()
        var openedAccountID: Account.ID?
        let coordinator = makeCoordinator(
            authorization: FakeAuthorization(
                status: .authorized,
                requestResult: .authorized
            ),
            deliverer: deliverer,
            toast: toast,
            openAccount: { openedAccountID = $0 }
        )
        coordinator.pollDidComplete(
            rows: [
                row(first, balance: 20),
                quotaRow(second, remaining: 60),
            ]
        )
        await coordinator.deliveryTask?.value

        coordinator.pollDidComplete(
            rows: [
                row(first, balance: 8),
                quotaRow(second, remaining: 5),
            ]
        )
        await coordinator.deliveryTask?.value

        #expect(deliverer.contents.count == 1)
        let content = try #require(deliverer.contents.first)
        #expect(content.affectedAccountIDs == [first.id, second.id])

        deliverer.openActions.first?()
        #expect(openedAccountID == first.id)
    }

    @Test
    func stayingInTheSameStateDoesNotDeliverTwice() async {
        let account = HealthTestSupport.balanceAccount()
        let deliverer = RecordingNotificationDeliverer()
        let toast = RecordingToastPresenter()
        let coordinator = makeCoordinator(
            authorization: FakeAuthorization(
                status: .authorized,
                requestResult: .authorized
            ),
            deliverer: deliverer,
            toast: toast
        )
        coordinator.pollDidComplete(rows: [row(account, balance: 20)])
        await coordinator.deliveryTask?.value

        coordinator.pollDidComplete(rows: [row(account, balance: 8)])
        await coordinator.deliveryTask?.value
        coordinator.pollDidComplete(rows: [row(account, balance: 7)])
        await coordinator.deliveryTask?.value

        #expect(deliverer.contents.count == 1)
        #expect(toast.contents.isEmpty)
    }

    @Test
    func staleAndErrorRowsNeverReachDelivery() async {
        let account = HealthTestSupport.balanceAccount()
        let authorization = FakeAuthorization(
            status: .authorized,
            requestResult: .authorized
        )
        let deliverer = RecordingNotificationDeliverer()
        let toast = RecordingToastPresenter()
        let coordinator = makeCoordinator(
            authorization: authorization,
            deliverer: deliverer,
            toast: toast
        )
        coordinator.pollDidComplete(rows: [row(account, balance: 20)])
        await coordinator.deliveryTask?.value

        coordinator.pollDidComplete(
            rows: [row(account, balance: 1, status: .stale)]
        )
        await coordinator.deliveryTask?.value
        coordinator.pollDidComplete(
            rows: [row(account, balance: 1, status: .error, error: .network)]
        )
        await coordinator.deliveryTask?.value

        #expect(deliverer.contents.isEmpty)
        #expect(toast.contents.isEmpty)
        // Permission is not even queried when there is nothing to deliver.
        #expect(authorization.permissionCallCount == 0)
    }

    // MARK: - Helpers

    private func makeCoordinator(
        authorization: FakeAuthorization,
        deliverer: RecordingNotificationDeliverer,
        toast: RecordingToastPresenter,
        openAccount: @escaping @MainActor (Account.ID) -> Void = { _ in }
    ) -> HealthNotificationCoordinator {
        HealthNotificationCoordinator(
            authorization: authorization,
            notificationDeliverer: deliverer,
            toastPresenter: toast,
            openAccount: openAccount
        )
    }

    private func row(
        _ account: Account,
        balance: Decimal,
        status: SnapshotStatus = .fresh,
        error: BalanceProviderError? = nil
    ) -> BalanceRow {
        HealthTestSupport.balanceRow(
            account,
            balance: balance,
            status: status,
            error: error
        )
    }

    private func quotaRow(_ account: Account, remaining: Decimal) -> BalanceRow {
        HealthTestSupport.quotaRow(account, remainingPercent: remaining)
    }
}

@MainActor
private final class FakeAuthorization: NotificationAuthorizationProviding {
    private let status: NotificationPermission
    private let requestResult: NotificationPermission
    private(set) var permissionCallCount = 0
    private(set) var requestCallCount = 0

    init(status: NotificationPermission, requestResult: NotificationPermission) {
        self.status = status
        self.requestResult = requestResult
    }

    func permission() async -> NotificationPermission {
        permissionCallCount += 1
        return status
    }

    func requestPermission() async -> NotificationPermission {
        requestCallCount += 1
        return requestResult
    }
}

@MainActor
private final class RecordingNotificationDeliverer: NotificationDelivering {
    private(set) var contents: [HealthNotificationContent] = []
    private(set) var openActions: [@MainActor () -> Void] = []

    func deliver(
        _ content: HealthNotificationContent,
        onOpen: @escaping @MainActor () -> Void
    ) async {
        contents.append(content)
        openActions.append(onOpen)
    }
}

@MainActor
private final class RecordingToastPresenter: HealthToastPresenting {
    private(set) var contents: [HealthNotificationContent] = []
    private(set) var openActions: [@MainActor () -> Void] = []

    func show(
        _ content: HealthNotificationContent,
        onOpen: @escaping @MainActor () -> Void
    ) {
        contents.append(content)
        openActions.append(onOpen)
    }
}
