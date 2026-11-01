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

    @Test
    func staleRowKeepsTheLastKnownBalanceAndIsMarkedStale() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-900),
            isAvailable: true
        )
        let row = BalanceRow(account: account, snapshot: snapshot, status: .stale)

        let viewState = BalanceRowPresentation.viewState(for: row, now: now)

        #expect(viewState.balanceText == "¥42.50")
        #expect(viewState.statusText == "已过期")
        #expect(viewState.status == .stale)
    }

    @Test
    func detailViewStateIncludesBreakdownFieldsWhenSnapshotProvidesThem() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "128.40")!, currency: .cny),
            fetchedAt: now,
            isAvailable: true,
            breakdown: [
                BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "28.456789")!),
                BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "100")!),
            ]
        )
        let row = BalanceRow(account: account, snapshot: snapshot, status: .fresh)

        let detail = BalanceRowPresentation.detailViewState(for: row, timeZone: utc)

        #expect(detail.breakdown.map(\.label) == ["赠送余额", "充值余额"])
        #expect(detail.breakdown.map(\.amountText) == ["¥28.456789", "¥100"])
    }

    @Test
    func rowsRoundToTwoDecimalsWhileDetailKeepsTheOriginalPrecision() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .moonshot, label: "Kimi 主账号")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "128.456789")!, currency: .cny),
            fetchedAt: now,
            isAvailable: true
        )
        let row = BalanceRow(account: account, snapshot: snapshot, status: .fresh)

        let rowState = BalanceRowPresentation.viewState(for: row, now: now)
        let detail = BalanceRowPresentation.detailViewState(for: row, timeZone: utc)

        #expect(rowState.balanceText == "¥128.46")
        #expect(detail.balanceText == "¥128.456789")
    }

    @Test
    func detailViewStateShowsTheExactFetchTimeInTheGivenTimeZone() {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .siliconFlow, label: "国内账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "15.00")!, currency: .cny),
            fetchedAt: fetchedAt,
            isAvailable: true
        )
        let row = BalanceRow(account: account, snapshot: snapshot, status: .fresh)

        let detail = BalanceRowPresentation.detailViewState(for: row, timeZone: utc)

        #expect(detail.fetchedAtText == "2027-01-15 08:00:00")
    }

    @Test(arguments: [
        (BalanceProviderError.authentication, Provider.deepSeek, "认证失败，请检查 API 密钥。"),
        (
            BalanceProviderError.authentication,
            Provider.moonshot,
            "认证失败，请检查 API 密钥，并确认所选区域与凭证匹配。"
        ),
        (BalanceProviderError.permission, Provider.deepSeek, "权限不足，请检查密钥权限。"),
        (BalanceProviderError.permission, Provider.openRouter, "权限不足，OpenRouter 需要管理密钥。"),
        (BalanceProviderError.network, Provider.moonshot, "网络错误，请检查网络连接。"),
        (BalanceProviderError.rateLimit, Provider.deepSeek, "请求过于频繁，请稍后重试。"),
        (BalanceProviderError.malformedResponse, Provider.siliconFlow, "响应格式异常，无法解析。"),
        (BalanceProviderError.unknown, Provider.openRouter, "未知错误，请稍后重试。"),
    ])
    func detailViewStateMapsTypedErrorsToChineseDetail(
        error: BalanceProviderError,
        provider: Provider,
        expectedText: String
    ) {
        let account = Account(id: UUID(), provider: provider, label: "账户")
        let row = BalanceRow(account: account, snapshot: nil, status: .error, error: error)

        let detail = BalanceRowPresentation.detailViewState(for: row, timeZone: utc)

        #expect(detail.errorText == expectedText)
    }

    @Test
    func detailViewStateKeepsTheLastSnapshotWhenTheAccountAlsoHasAnError() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "128.40")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-900),
            isAvailable: true,
            breakdown: [
                BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "28.40")!),
            ]
        )
        let row = BalanceRow(
            account: account,
            snapshot: snapshot,
            status: .error,
            error: .network
        )

        let detail = BalanceRowPresentation.detailViewState(for: row, timeZone: utc)

        #expect(detail.balanceText == "¥128.4")
        #expect(detail.fetchedAtText == "2027-01-15 07:45:00")
        #expect(detail.breakdown.map(\.amountText) == ["¥28.4"])
        #expect(detail.errorText == "网络错误，请检查网络连接。")
    }

    @Test
    func detailViewStateIsEmptyForARowThatHasNotLoadedYet() {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let row = BalanceRow(account: account, snapshot: nil, status: nil)

        let detail = BalanceRowPresentation.detailViewState(for: row, timeZone: utc)

        #expect(detail.balanceText == nil)
        #expect(detail.fetchedAtText == nil)
        #expect(detail.breakdown.isEmpty)
        #expect(detail.errorText == nil)
    }
}

private let utc = TimeZone(identifier: "UTC")!
