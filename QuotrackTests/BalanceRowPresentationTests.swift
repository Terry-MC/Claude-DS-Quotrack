import Foundation
import Testing

struct BalanceRowPresentationTests {
    @Test
    func rowViewStateShowsProviderAccountBalanceAndRelativeTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-300),
            isAvailable: true
        )
        let row = BalanceRow(account: account, snapshot: snapshot, status: .fresh)

        let viewState = BalanceRowPresentation.viewState(for: row, now: now)

        #expect(viewState.providerName == "DeepSeek")
        #expect(viewState.label == "个人账户")
        #expect(viewState.balanceText == "¥42.50")
        #expect(viewState.updatedText == "5分钟前")
        #expect(viewState.statusText == "正常")
    }
}
