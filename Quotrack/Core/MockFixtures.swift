import Foundation

/// One mock Account and what the mock Provider reports for it.
struct MockFixture: Equatable, Sendable {
    let account: Account
    let outcome: MockOutcome
}

enum MockOutcome: Equatable, Sendable {
    case balance(Balance, breakdown: [BalanceBreakdownItem]?, fetchedAt: Date)
    case failure(BalanceProviderError)
}

/// The deterministic fixture set shared by mock mode and its tests. It covers
/// every addable Provider, several Accounts per Provider, a low Balance, all
/// typed error categories, a Stale Snapshot, and a legacy SiliconFlow Account
/// that must render as unsupported.
enum MockFixtures {
    /// A Quota fixture outside the Balance fixture list. Mock mode appends it
    /// so the Kimi Code row, badge, progress bar, and reset text are visible.
    static func subscriptionAccount() -> Account {
        Account(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            provider: .moonshot,
            kind: .subscription,
            label: "Kimi Code",
            warningThreshold: 20,
            criticalThreshold: 10
        )
    }

    static func standard(now: Date) -> [MockFixture] {
        [
            fixture(
                provider: .deepSeek,
                label: "个人账户",
                amount: "128.40",
                currency: .cny,
                age: 120,
                now: now,
                breakdown: [
                    BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "28.40")!),
                    BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "100.00")!),
                ]
            ),
            fixture(
                provider: .deepSeek,
                label: "工作账户",
                amount: "0.80",
                currency: .cny,
                age: 60,
                now: now,
                warningThreshold: Decimal(string: "5.00")!
            ),
            fixture(
                provider: .moonshot,
                label: "Kimi 主账号",
                amount: "42.50",
                currency: .cny,
                age: 1_200,
                now: now,
                breakdown: [
                    BalanceBreakdownItem(kind: .voucher, amount: Decimal(string: "2.50")!),
                    BalanceBreakdownItem(kind: .cash, amount: Decimal(string: "40.00")!),
                ]
            ),
            fixture(
                provider: .siliconFlow,
                label: "SiliconFlow 国内",
                amount: "15.00",
                currency: .cny,
                age: 180,
                now: now,
                breakdown: [
                    BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "5.00")!),
                    BalanceBreakdownItem(kind: .cash, amount: Decimal(string: "10.00")!),
                ]
            ),
            fixture(
                provider: .openRouter,
                label: "OpenRouter 管理",
                amount: "18.75",
                currency: .usd,
                age: 240,
                now: now,
                breakdown: [
                    BalanceBreakdownItem(kind: .totalCredits, amount: Decimal(string: "30.00")!),
                    BalanceBreakdownItem(kind: .spend, amount: Decimal(string: "11.25")!),
                ]
            ),
            failure(provider: .deepSeek, label: "DeepSeek 限流", error: .rateLimit),
            failure(
                provider: .deepSeek,
                label: "DeepSeek 限流重试",
                error: .rateLimit(retryAfter: 120)
            ),
            failure(provider: .moonshot, label: "Kimi 网络异常", error: .network),
            failure(provider: .deepSeek, label: "DeepSeek 认证失败", error: .authentication),
            failure(provider: .moonshot, label: "Kimi 响应异常", error: .malformedResponse),
            failure(provider: .openRouter, label: "OpenRouter 权限不足", error: .permission),
            failure(provider: .openRouter, label: "OpenRouter 未知错误", error: .unknown),
        ]
    }

    private static func failure(
        provider: Provider,
        label: String,
        error: BalanceProviderError
    ) -> MockFixture {
        MockFixture(
            account: Account(id: UUID(), provider: provider, label: label),
            outcome: .failure(error)
        )
    }

    private static func fixture(
        provider: Provider,
        label: String,
        amount: String,
        currency: Currency,
        age: TimeInterval,
        now: Date,
        breakdown: [BalanceBreakdownItem]? = nil,
        warningThreshold: Decimal? = nil
    ) -> MockFixture {
        let account = Account(
            id: UUID(),
            provider: provider,
            label: label,
            warningThreshold: warningThreshold
        )
        return MockFixture(
            account: account,
            outcome: .balance(
                Balance(amount: Decimal(string: amount)!, currency: currency),
                breakdown: breakdown,
                fetchedAt: now.addingTimeInterval(-age)
            )
        )
    }
}
