import Foundation
import Testing

struct HealthPresentationTests {
    @Test
    func freshBalanceAtTheWarningLineIsWarning() {
        let viewState = makeViewState(amount: "10", warning: "10")

        #expect(viewState.tone == .warning)
    }

    @Test
    func freshBalanceBelowTheWarningLineIsWarning() {
        let viewState = makeViewState(amount: "9.99", warning: "10")

        #expect(viewState.tone == .warning)
    }

    @Test
    func freshBalanceAboveTheWarningLineIsNormal() {
        let viewState = makeViewState(amount: "10.01", warning: "10")

        #expect(viewState.tone == .normal)
    }

    @Test
    func freshBalanceAtTheCriticalLineIsCritical() {
        let viewState = makeViewState(
            amount: "5",
            warning: "10",
            critical: "5"
        )

        #expect(viewState.tone == .critical)
    }

    @Test
    func freshBalanceBelowTheCriticalLineIsCritical() {
        let viewState = makeViewState(
            amount: "4.99",
            warning: "10",
            critical: "5"
        )

        #expect(viewState.tone == .critical)
    }

    @Test
    func errorRowsDoNotShowAnEvaluatedHealthPill() {
        let viewState = makeViewState(
            amount: "1",
            warning: "10",
            status: .error,
            error: .network
        )

        #expect(!viewState.showsHealth)
    }

    @Test
    func staleSnapshotStaysGrayEvenBelowTheThreshold() {
        let viewState = makeViewState(
            amount: "1",
            warning: "50",
            status: .stale,
            age: 3_600
        )

        #expect(viewState.tone == .stale)
    }

    @Test
    func errorRowIsRedEvenBelowTheThreshold() {
        let viewState = makeViewState(
            amount: "1",
            warning: "50",
            status: .error,
            error: .network
        )

        #expect(viewState.tone == .error)
    }

    @Test
    func unavailableSnapshotKeepsItsOwnTone() {
        let viewState = makeViewState(
            amount: "1",
            warning: "50",
            status: .unavailable,
            isAvailable: false
        )

        #expect(viewState.tone == .unavailable)
    }

    @Test
    func rowThatHasNotLoadedYetIsPending() {
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户",
            warningThreshold: 50
        )
        let row = BalanceRow(account: account, snapshot: nil, status: nil)

        let viewState = BalanceRowPresentation.viewState(
            for: row,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        #expect(viewState.tone == .pending)
    }

    @Test
    func freshBalanceWithoutThresholdsIsUnset() {
        let viewState = makeViewState(amount: "0.01")

        #expect(viewState.tone == .unset)
        #expect(viewState.health == .unset)
    }

    private func makeViewState(
        amount: String,
        warning: String? = nil,
        critical: String? = nil,
        status: SnapshotStatus = .fresh,
        age: TimeInterval = 0,
        isAvailable: Bool = true,
        error: BalanceProviderError? = nil
    ) -> BalanceRowViewState {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户",
            warningThreshold: warning.flatMap { Decimal(string: $0) },
            criticalThreshold: critical.flatMap { Decimal(string: $0) }
        )
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: amount)!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-age),
            isAvailable: isAvailable
        )
        let row = BalanceRow(
            account: account,
            snapshot: .balance(snapshot),
            status: status,
            error: error
        )
        return BalanceRowPresentation.viewState(for: row, now: now)
    }
}
