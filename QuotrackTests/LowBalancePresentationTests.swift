import Foundation
import Testing

struct LowBalancePresentationTests {
    @Test
    func freshBalanceBelowTheAccountThresholdIsMarkedLowBalance() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户",
            lowBalanceThreshold: Decimal(string: "10")
        )
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "9.99")!, currency: .cny),
            fetchedAt: now,
            isAvailable: true
        )
        let row = BalanceRow(account: account, snapshot: .balance(snapshot), status: .fresh)

        let viewState = BalanceRowPresentation.viewState(for: row, now: now)

        #expect(viewState.tone == .lowBalance)
    }

    @Test(arguments: [
        ("equal to the threshold", "10.00", "10"),
        ("above the threshold", "10.01", "10"),
    ])
    func freshBalanceAtOrAboveTheThresholdIsNormal(
        _: String,
        balanceAmount: String,
        threshold: String
    ) {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户",
            lowBalanceThreshold: Decimal(string: threshold)
        )
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: balanceAmount)!, currency: .cny),
            fetchedAt: now,
            isAvailable: true
        )
        let row = BalanceRow(account: account, snapshot: .balance(snapshot), status: .fresh)

        let viewState = BalanceRowPresentation.viewState(for: row, now: now)

        #expect(viewState.tone == .normal)
    }

    @Test
    func staleSnapshotStaysGrayEvenBelowTheThreshold() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(
            id: UUID(),
            provider: .moonshot,
            label: "Kimi 主账号",
            lowBalanceThreshold: Decimal(string: "50")
        )
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "1.00")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-3_600),
            isAvailable: true
        )
        let row = BalanceRow(account: account, snapshot: .balance(snapshot), status: .stale)

        let viewState = BalanceRowPresentation.viewState(for: row, now: now)

        #expect(viewState.tone == .stale)
    }

    @Test
    func errorRowIsRedEvenBelowTheThreshold() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户",
            lowBalanceThreshold: Decimal(string: "50")
        )
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "1.00")!, currency: .cny),
            fetchedAt: now,
            isAvailable: true
        )
        let row = BalanceRow(account: account, snapshot: .balance(snapshot), status: .error, error: .network)

        let viewState = BalanceRowPresentation.viewState(for: row, now: now)

        #expect(viewState.tone == .error)
    }

    @Test
    func unavailableSnapshotKeepsItsOwnTone() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户",
            lowBalanceThreshold: Decimal(string: "50")
        )
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "1.00")!, currency: .cny),
            fetchedAt: now,
            isAvailable: false
        )
        let row = BalanceRow(account: account, snapshot: .balance(snapshot), status: .unavailable)

        let viewState = BalanceRowPresentation.viewState(for: row, now: now)

        #expect(viewState.tone == .unavailable)
    }

    @Test
    func rowThatHasNotLoadedYetIsPending() {
        let account = Account(
            id: UUID(),
            provider: .siliconFlow,
            label: "SiliconFlow 国内",
            lowBalanceThreshold: Decimal(string: "50")
        )
        let row = BalanceRow(account: account, snapshot: nil, status: nil)

        let viewState = BalanceRowPresentation.viewState(
            for: row,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        #expect(viewState.tone == .pending)
    }

    @Test
    func freshBalanceWithTheWarningDisabledIsNormal() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "0.01")!, currency: .cny),
            fetchedAt: now,
            isAvailable: true
        )
        let row = BalanceRow(account: account, snapshot: .balance(snapshot), status: .fresh)

        let viewState = BalanceRowPresentation.viewState(for: row, now: now)

        #expect(viewState.tone == .normal)
    }
}
