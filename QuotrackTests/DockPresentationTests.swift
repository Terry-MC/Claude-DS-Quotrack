import Foundation
import Testing

/// The dock is a pure view state: Health counts and severity come from the same
/// evaluator as the panel and menu bar, so the badge can never disagree with
/// the rows.
struct DockPresentationTests {
    @Test
    func noAccountsProducesANormalDockWithNoBadge() {
        let presentation = DockPresentation.make(healths: [], reduceMotion: false)

        #expect(presentation.status == .normal)
        #expect(presentation.badgeCount == 0)
        #expect(presentation.badgeText == nil)
        #expect(!presentation.isPulsing)
    }

    @Test
    func theBadgeCountsAccountsInWarningOrCritical() {
        let presentation = DockPresentation.make(
            healths: [.normal, .warning, .unset, .critical, .warning],
            reduceMotion: false
        )

        #expect(presentation.badgeCount == 3)
        #expect(presentation.badgeText == "3")
        #expect(presentation.status == .critical)
    }

    @Test
    func warningAccountsColorTheDockWarningWithoutPulsing() {
        let presentation = DockPresentation.make(
            healths: [.normal, .warning],
            reduceMotion: false
        )

        #expect(presentation.status == .warning)
        #expect(presentation.badgeCount == 1)
        #expect(!presentation.isPulsing)
    }

    @Test
    func normalAndUnsetAccountsDoNotRaiseTheDock() {
        let presentation = DockPresentation.make(
            healths: [.normal, .unset, .normal],
            reduceMotion: false
        )

        #expect(presentation.status == .normal)
        #expect(presentation.badgeCount == 0)
    }

    @Test
    func aCriticalDockPulsesUnlessReduceMotionIsOn() {
        let pulsing = DockPresentation.make(healths: [.critical], reduceMotion: false)
        let still = DockPresentation.make(healths: [.critical], reduceMotion: true)

        #expect(pulsing.status == .critical)
        #expect(pulsing.isPulsing)
        #expect(still.status == .critical)
        #expect(!still.isPulsing)
    }

    @Test
    func aWarningDockNeverPulses() {
        let presentation = DockPresentation.make(healths: [.warning], reduceMotion: false)

        #expect(!presentation.isPulsing)
    }

    @Test
    func theBadgeTextCapsAtNinetyNine() {
        let ninetyNine = DockPresentation.make(
            healths: Array(repeating: .warning, count: 99),
            reduceMotion: false
        )
        let oneHundred = DockPresentation.make(
            healths: Array(repeating: .critical, count: 100),
            reduceMotion: false
        )

        #expect(ninetyNine.badgeCount == 99)
        #expect(ninetyNine.badgeText == "99")
        #expect(oneHundred.badgeCount == 100)
        #expect(oneHundred.badgeText == "99+")
    }

    @Test
    func rowsDeriveHealthThroughTheSharedEvaluator() {
        let rows = [
            makeRow(warning: "10", critical: "5", amount: "20"),
            makeRow(warning: "10", critical: "5", amount: "7"),
            makeRow(warning: "10", critical: "5", amount: "4.5"),
            makeRow(amount: "0"),
        ]

        let presentation = DockPresentation.make(rows: rows, reduceMotion: false)

        #expect(presentation.status == .critical)
        #expect(presentation.badgeCount == 2)
    }

    @Test
    func aStaleCriticalAccountStillCounts() {
        let rows = [
            makeRow(status: .stale, warning: "10", critical: "5", amount: "4"),
        ]

        let presentation = DockPresentation.make(rows: rows, reduceMotion: false)

        #expect(presentation.status == .critical)
        #expect(presentation.badgeCount == 1)
    }

    @Test
    func anUnsupportedAccountDoesNotRaiseTheDock() {
        let rows = [
            makeRow(
                provider: .siliconFlow,
                warning: "10",
                critical: "5",
                amount: "1"
            ),
        ]

        let presentation = DockPresentation.make(rows: rows, reduceMotion: false)

        #expect(presentation.status == .normal)
        #expect(presentation.badgeCount == 0)
    }

    @Test
    func theAccessibilityDescriptionNamesTheStateAndCount() {
        let normal = DockPresentation.make(healths: [.normal], reduceMotion: false)
        let warning = DockPresentation.make(
            healths: [.warning, .warning],
            reduceMotion: false
        )
        let critical = DockPresentation.make(
            healths: [.warning, .critical, .critical],
            reduceMotion: true
        )

        #expect(normal.accessibilityDescription == "Quotrack：一切正常")
        #expect(warning.accessibilityDescription == "Quotrack：2 个账户需要关注")
        #expect(critical.accessibilityDescription == "Quotrack：3 个账户需要立即处理")
    }
}

private func makeRow(
    status: SnapshotStatus? = .fresh,
    provider: Provider = .deepSeek,
    warning: String? = nil,
    critical: String? = nil,
    amount: String
) -> BalanceRow {
    let account = Account(
        id: UUID(),
        provider: provider,
        label: "账户",
        warningThreshold: warning.flatMap { Decimal(string: $0) },
        criticalThreshold: critical.flatMap { Decimal(string: $0) }
    )
    let snapshot = status.map { _ in
        AccountSnapshot.balance(
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: Decimal(string: amount)!, currency: .cny),
                fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
                isAvailable: true
            )
        )
    }
    return BalanceRow(account: account, snapshot: snapshot, status: status)
}
