import Foundation
import Testing

struct PanelHeaderPresentationTests {
    @Test
    func healthCountsSeparateNormalWarningCriticalAndError() {
        let rows = [
            makeRow(status: .fresh, warning: "10", amount: "50"),
            makeRow(status: .fresh, warning: "10", amount: "5"),
            makeRow(status: .fresh, warning: "10", critical: "5", amount: "5"),
            makeRow(status: .stale, amount: "5"),
            makeRow(status: .error, error: .network),
        ]

        let header = PanelHeaderPresentation.viewState(for: rows)

        #expect(header.healthyCount == 1)
        #expect(header.warningCount == 2)
        #expect(header.criticalCount == 1)
        #expect(header.errorCount == 1)
        #expect(header.healthyText == "正常 1")
        #expect(header.warningText == "预警 2")
        #expect(header.criticalText == "紧急 1")
        #expect(header.errorText == "错误 1")
    }

    @Test
    func theHeaderCarriesTheDisplayNameAndChineseSubtitle() {
        let header = PanelHeaderPresentation.viewState(for: [])

        #expect(header.title == "Quotrack")
        #expect(header.subtitle == "AI 余额监控")
    }

    @Test
    func rowsStillLoadingAreCountedAsNeitherHealthyNorInError() {
        let rows = [makeRow(status: nil)]

        let header = PanelHeaderPresentation.viewState(for: rows)

        #expect(header.healthyCount == 0)
        #expect(header.warningCount == 0)
        #expect(header.criticalCount == 0)
        #expect(header.errorCount == 0)
    }

    @Test
    func unsupportedRowsAreCountedAsNeitherHealthyNorInError() {
        let rows = [makeRow(status: .unsupported)]

        let header = PanelHeaderPresentation.viewState(for: rows)

        #expect(header.healthyCount == 0)
        #expect(header.warningCount == 0)
        #expect(header.criticalCount == 0)
        #expect(header.errorCount == 0)
    }
}

private func makeRow(
    status: SnapshotStatus?,
    warning: String? = nil,
    critical: String? = nil,
    amount: String = "10",
    error: BalanceProviderError? = nil
) -> BalanceRow {
    let account = Account(
        id: UUID(),
        provider: .deepSeek,
        label: "账户",
        warningThreshold: warning.flatMap { Decimal(string: $0) },
        criticalThreshold: critical.flatMap { Decimal(string: $0) }
    )
    let snapshot = status.map { _ in
        BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: amount)!, currency: .cny),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: status != .unavailable
        )
    }
    return BalanceRow(
        account: account,
        snapshot: snapshot.map(AccountSnapshot.balance),
        status: status,
        error: error
    )
}
