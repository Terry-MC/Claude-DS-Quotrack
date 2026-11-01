import Foundation
import Testing

struct PanelHeaderPresentationTests {
    @Test
    func lowBalanceWarningsDoNotChangeHealthyOrErrorCounts() {
        let rows = [
            makeRow(status: .fresh, threshold: "10", amount: "50"),
            makeRow(status: .fresh, threshold: "10", amount: "5"),
            makeRow(status: .stale, amount: "5"),
            makeRow(status: .error, error: .network),
        ]

        let header = PanelHeaderPresentation.viewState(for: rows)

        #expect(header.healthyCount == 2)
        #expect(header.errorCount == 1)
        #expect(header.healthyText == "正常 2")
        #expect(header.errorText == "错误 1")
    }

    @Test
    func rowsStillLoadingAreCountedAsNeitherHealthyNorInError() {
        let rows = [makeRow(status: nil)]

        let header = PanelHeaderPresentation.viewState(for: rows)

        #expect(header.healthyCount == 0)
        #expect(header.errorCount == 0)
    }
}

private func makeRow(
    status: SnapshotStatus?,
    threshold: String? = nil,
    amount: String = "10",
    error: BalanceProviderError? = nil
) -> BalanceRow {
    let account = Account(
        id: UUID(),
        provider: .deepSeek,
        label: "账户",
        lowBalanceThreshold: threshold.flatMap { Decimal(string: $0) }
    )
    let snapshot = status.map { _ in
        BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: amount)!, currency: .cny),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: status != .unavailable
        )
    }
    return BalanceRow(account: account, snapshot: snapshot, status: status, error: error)
}
