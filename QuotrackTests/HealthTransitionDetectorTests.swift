import Foundation
import Testing

/// Health notifications are driven only by transitions between evaluable
/// Health states. The first observation of an Account establishes its baseline
/// and never notifies, and Stale, error, unavailable, unsupported, or unset
/// rows never notify.
struct HealthTransitionDetectorTests {
    // MARK: - Transitions

    @Test
    func firstObservationEstablishesABaselineWithoutNotifying() {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()

        #expect(detector.observe(rows: [row(account, balance: 8)]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: 8)]).isEmpty)
    }

    @Test
    func normalToWarningNotifies() throws {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])

        let batch = detector.observe(rows: [row(account, balance: 10)])

        let transition = try #require(batch.transitions.first)
        #expect(batch.transitions.count == 1)
        #expect(transition.accountID == account.id)
        #expect(transition.from == .normal)
        #expect(transition.to == .warning)
    }

    @Test
    func warningToCriticalNotifies() throws {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])
        _ = detector.observe(rows: [row(account, balance: 8)])

        let batch = detector.observe(rows: [row(account, balance: 5)])

        let transition = try #require(batch.transitions.first)
        #expect(batch.transitions.count == 1)
        #expect(transition.from == .warning)
        #expect(transition.to == .critical)
    }

    @Test
    func criticalToWarningNotifies() throws {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])
        _ = detector.observe(rows: [row(account, balance: 8)])
        _ = detector.observe(rows: [row(account, balance: 5)])

        let batch = detector.observe(rows: [row(account, balance: 6)])

        let transition = try #require(batch.transitions.first)
        #expect(batch.transitions.count == 1)
        #expect(transition.from == .critical)
        #expect(transition.to == .warning)
    }

    @Test
    func warningToNormalNotifiesRecovery() throws {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])
        _ = detector.observe(rows: [row(account, balance: 8)])

        let batch = detector.observe(rows: [row(account, balance: 20)])

        let transition = try #require(batch.transitions.first)
        #expect(batch.transitions.count == 1)
        #expect(transition.from == .warning)
        #expect(transition.to == .normal)
    }

    @Test
    func stayingInTheSameStateNeverNotifiesTwice() {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])
        #expect(detector.observe(rows: [row(account, balance: 8)]).transitions.count == 1)

        for balance in [Decimal(9), Decimal(7), Decimal(6), Decimal(string: "5.5")!] {
            #expect(detector.observe(rows: [row(account, balance: balance)]).isEmpty)
        }
    }

    @Test
    func aDirectJumpIntoCriticalNotifies() throws {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])

        let batch = detector.observe(rows: [row(account, balance: 5)])

        let transition = try #require(batch.transitions.first)
        #expect(transition.from == .normal)
        #expect(transition.to == .critical)
    }

    @Test
    func aDirectRecoveryFromCriticalNotifies() throws {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])
        _ = detector.observe(rows: [row(account, balance: 5)])

        let batch = detector.observe(rows: [row(account, balance: 20)])

        let transition = try #require(batch.transitions.first)
        #expect(transition.from == .critical)
        #expect(transition.to == .normal)
    }

    // MARK: - Balance hysteresis

    @Test
    func balanceWarningIsHeldUntilTheValueExceedsFivePercentAboveTheThreshold() {
        let account = HealthTestSupport.balanceAccount(warning: 10, critical: 5)
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])

        // Enter warning exactly at the threshold.
        #expect(detector.observe(rows: [row(account, balance: 10)]).transitions.map(\.to) == [.warning])
        // 10 * 5% = 0.5. The state is held at and below 10.5.
        #expect(detector.observe(rows: [row(account, balance: decimal("10.4"))]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: decimal("10.5"))]).isEmpty)
        // Only crossing the band returns to normal.
        #expect(detector.observe(rows: [row(account, balance: decimal("10.51"))]).transitions.map(\.to) == [.normal])
    }

    @Test
    func balanceCriticalIsHeldUntilTheValueExceedsFivePercentAboveTheThreshold() {
        let account = HealthTestSupport.balanceAccount(warning: 10, critical: 5)
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])
        _ = detector.observe(rows: [row(account, balance: 8)])
        #expect(detector.observe(rows: [row(account, balance: 5)]).transitions.map(\.to) == [.critical])

        // 5 * 5% = 0.25. The critical state is held at and below 5.25.
        #expect(detector.observe(rows: [row(account, balance: decimal("5.24"))]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: decimal("5.25"))]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: decimal("5.26"))]).transitions.map(\.to) == [.warning])
    }

    @Test
    func aValueHoveringAtTheWarningThresholdFlapsOnlyOutsideTheBand() {
        let account = HealthTestSupport.balanceAccount(warning: 10, critical: 5)
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])

        var transitions = 0
        for balance in ["10", "10.2", "9.8", "10.4", "10.3", "9.9"] {
            transitions += detector.observe(
                rows: [row(account, balance: decimal(balance))]
            ).transitions.count
        }

        #expect(transitions == 1)
    }

    @Test
    func theHysteresisBandIsRelativeToEachBalanceThreshold() {
        // Warning 100 has a 5-point band; critical 40 has a 2-point band.
        let account = HealthTestSupport.balanceAccount(warning: 100, critical: 40)
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 200)])
        #expect(detector.observe(rows: [row(account, balance: 100)]).transitions.map(\.to) == [.warning])
        #expect(detector.observe(rows: [row(account, balance: 105)]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: 105.01)]).transitions.map(\.to) == [.normal])

        #expect(detector.observe(rows: [row(account, balance: 40)]).transitions.map(\.to) == [.critical])
        #expect(detector.observe(rows: [row(account, balance: 42)]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: 42.01)]).transitions.map(\.to) == [.warning])
    }

    // MARK: - Quota hysteresis

    @Test
    func quotaWarningUsesAFivePercentagePointBand() {
        let account = HealthTestSupport.quotaAccount(warning: 20, critical: 10)
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [quotaRow(account, remaining: 60)])

        #expect(detector.observe(rows: [quotaRow(account, remaining: 20)]).transitions.map(\.to) == [.warning])
        #expect(detector.observe(rows: [quotaRow(account, remaining: 24)]).isEmpty)
        #expect(detector.observe(rows: [quotaRow(account, remaining: 25)]).isEmpty)
        #expect(detector.observe(rows: [quotaRow(account, remaining: decimal("25.01"))]).transitions.map(\.to) == [.normal])
    }

    @Test
    func quotaCriticalUsesAFivePercentagePointBand() {
        let account = HealthTestSupport.quotaAccount(warning: 20, critical: 10)
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [quotaRow(account, remaining: 60)])
        _ = detector.observe(rows: [quotaRow(account, remaining: 15)])
        #expect(detector.observe(rows: [quotaRow(account, remaining: 10)]).transitions.map(\.to) == [.critical])

        #expect(detector.observe(rows: [quotaRow(account, remaining: 14)]).isEmpty)
        #expect(detector.observe(rows: [quotaRow(account, remaining: 15)]).isEmpty)
        #expect(detector.observe(rows: [quotaRow(account, remaining: decimal("15.01"))]).transitions.map(\.to) == [.warning])
    }

    // MARK: - Unset thresholds

    @Test
    func anAccountWithNoThresholdsNeverNotifies() {
        let account = HealthTestSupport.balanceAccount(warning: nil, critical: nil)
        var detector = HealthTransitionDetector()

        _ = detector.observe(rows: [row(account, balance: 20)])
        #expect(detector.observe(rows: [row(account, balance: 0)]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: 100)]).isEmpty)
    }

    @Test
    func aWarningOnlyAccountHasNoCriticalState() {
        let account = HealthTestSupport.balanceAccount(warning: 10, critical: nil)
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])

        #expect(detector.observe(rows: [row(account, balance: 1)]).transitions.map(\.to) == [.warning])
        #expect(detector.observe(rows: [row(account, balance: 10)]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: 10.51)]).transitions.map(\.to) == [.normal])
    }

    @Test
    func aCriticalOnlyAccountNotifiesOnItsOwnBand() {
        let account = HealthTestSupport.balanceAccount(warning: nil, critical: 5)
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])

        #expect(detector.observe(rows: [row(account, balance: 5)]).transitions.map(\.to) == [.critical])
        // 5% of 5 = 0.25.
        #expect(detector.observe(rows: [row(account, balance: 5.25)]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: 5.26)]).transitions.map { ($0.from, $0.to) }.contains { $0 == (.critical, .normal) })
    }

    @Test
    func clearingThresholdsResetsTheBaselineWithoutNotifying() {
        let id = UUID()
        let warningAccount = HealthTestSupport.balanceAccount(id: id)
        let unsetAccount = HealthTestSupport.balanceAccount(
            id: id,
            warning: nil,
            critical: nil
        )
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(warningAccount, balance: 20)])
        _ = detector.observe(rows: [row(warningAccount, balance: 8)])

        #expect(detector.observe(rows: [row(unsetAccount, balance: 8)]).isEmpty)
        // Re-establishing a threshold starts a fresh baseline: it is not a
        // transition out of the unset state.
        #expect(detector.observe(rows: [row(warningAccount, balance: 8)]).isEmpty)
    }

    // MARK: - Stale, error, unavailable, and unsupported suppression

    @Test
    func staleRowsNeverNotifyAndDoNotDisturbTheRememberedState() {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])

        #expect(detector.observe(rows: [row(account, balance: 1, status: .stale)]).isEmpty)
        // The last fresh state was normal, so a fresh critical value is a
        // normal -> critical transition.
        let batch = detector.observe(rows: [row(account, balance: 1)])
        #expect(batch.transitions.map { ($0.from, $0.to) }.contains { $0 == (.normal, .critical) })
    }

    @Test
    func errorRowsNeverNotifyAndDoNotDisturbTheRememberedState() {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])
        _ = detector.observe(rows: [row(account, balance: 8)])

        let failed = row(account, balance: 1, status: .error, error: .network)
        #expect(detector.observe(rows: [failed]).isEmpty)
        // The account recovers to normal, so the notification is warning ->
        // normal even though the failed fetch carried a critical value.
        let batch = detector.observe(rows: [row(account, balance: 20)])
        #expect(batch.transitions.map { ($0.from, $0.to) }.contains { $0 == (.warning, .normal) })
    }

    @Test
    func unavailableRowsNeverNotify() {
        let account = HealthTestSupport.balanceAccount()
        var detector = HealthTransitionDetector()
        _ = detector.observe(rows: [row(account, balance: 20)])

        #expect(detector.observe(rows: [row(account, balance: 1, status: .unavailable)]).isEmpty)
        #expect(detector.observe(rows: [row(account, balance: 8)]).transitions.map(\.to) == [.warning])
    }

    @Test
    func unsupportedRowsNeverNotify() {
        let account = HealthTestSupport.balanceAccount(
            provider: .siliconFlow,
            warning: 10,
            critical: 5
        )
        var detector = HealthTransitionDetector()

        _ = detector.observe(rows: [row(account, balance: 20, status: .unsupported)])
        #expect(detector.observe(rows: [row(account, balance: 1, status: .unsupported)]).isEmpty)
    }

    @Test
    func aQuotaSnapshotThatCannotBeEvaluatedDoesNotNotify() {
        let account = HealthTestSupport.quotaAccount(warning: 20, critical: 10)
        var detector = HealthTransitionDetector()

        // limit 0 makes the remaining percentage undefined; the evaluator
        // reports unset.
        let invalid = BalanceRow(
            account: account,
            snapshot: .quota(
                QuotaSnapshot(
                    accountID: account.id,
                    limit: 0,
                    remaining: 0,
                    fetchedAt: HealthTestSupport.now
                )
            ),
            status: .fresh
        )
        #expect(detector.observe(rows: [invalid]).isEmpty)
        #expect(detector.observe(rows: [quotaRow(account, remaining: 5)]).isEmpty)
    }

    // MARK: - Aggregation

    @Test
    func transitionsFromOnePollAreAggregatedInRowOrder() throws {
        let first = HealthTestSupport.balanceAccount(label: "第一个")
        let second = HealthTestSupport.quotaAccount(label: "第二个")
        var detector = HealthTransitionDetector()
        _ = detector.observe(
            rows: [
                row(first, balance: 20),
                quotaRow(second, remaining: 60),
            ]
        )

        let batch = detector.observe(
            rows: [
                row(first, balance: 8),
                quotaRow(second, remaining: 5),
            ]
        )

        #expect(batch.transitions.count == 2)
        #expect(batch.transitions.map(\.accountID) == [first.id, second.id])
        #expect(batch.transitions.map(\.to) == [.warning, .critical])
        #expect(batch.firstAffectedAccountID == first.id)
    }

    @Test
    func anEmptyBatchHasNoFirstAffectedAccount() {
        #expect(HealthNotificationBatch(transitions: []).firstAffectedAccountID == nil)
    }

    // MARK: - Helpers

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

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value)!
    }
}
