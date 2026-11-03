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

/// One mock Quota Account and the QuotaSnapshot the mock Provider reports for
/// it. Quota fixtures are separate from Balance fixtures because the two
/// Metrics are never mixed in one response.
struct MockQuotaFixture: Equatable, Sendable {
    let account: Account
    let snapshot: QuotaSnapshot
}

/// The deterministic fixture set shared by mock mode and its tests. It covers
/// every addable Provider, every Balance and Quota Health state, mixed kinds
/// under Moonshot, all typed error categories, a Stale Snapshot, and a legacy
/// SiliconFlow Account that must render as unsupported.
enum MockFixtures {
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
                ],
                warningThreshold: Decimal(string: "100.00")!,
                criticalThreshold: Decimal(string: "50.00")!
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
                provider: .deepSeek,
                label: "DeepSeek 紧急",
                amount: "2.00",
                currency: .cny,
                age: 30,
                now: now,
                criticalThreshold: Decimal(string: "5.00")!
            ),
            fixture(
                provider: .deepSeek,
                label: "DeepSeek 零余额",
                amount: "0.00",
                currency: .cny,
                age: 45,
                now: now,
                warningThreshold: Decimal(string: "5.00")!,
                criticalThreshold: Decimal(string: "1.00")!
            ),
            fixture(
                provider: .deepSeek,
                label: "DeepSeek 负余额",
                amount: "-1.00",
                currency: .cny,
                age: 50,
                now: now,
                warningThreshold: Decimal(string: "5.00")!,
                criticalThreshold: Decimal(string: "1.00")!
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
                ],
                warningThreshold: Decimal(string: "50.00")!,
                criticalThreshold: Decimal(string: "20.00")!
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

    /// Quota fixtures cover normal, warning, critical, and unset Health. The
    /// normal Account deliberately has no secondary window so the UI exercises
    /// the "missing 5-hour window" layout; the others show the weekly quota
    /// plus a 5-hour window.
    static func quotaFixtures(now: Date) -> [MockQuotaFixture] {
        let resetAt = now.addingTimeInterval(86_400)
        return [
            quotaFixture(
                label: "Kimi Code 正常",
                remaining: 80,
                warningThreshold: 20,
                criticalThreshold: 10,
                windows: [],
                resetAt: resetAt,
                now: now
            ),
            quotaFixture(
                label: "Kimi Code 预警",
                remaining: 15,
                warningThreshold: 20,
                criticalThreshold: 10,
                resetAt: resetAt,
                now: now
            ),
            quotaFixture(
                label: "Kimi Code 紧急",
                remaining: 5,
                warningThreshold: 20,
                criticalThreshold: 10,
                resetAt: resetAt,
                now: now
            ),
            quotaFixture(
                label: "Kimi Code 未设置",
                remaining: 60,
                resetAt: resetAt,
                now: now
            ),
        ]
    }

    private static func quotaFixture(
        label: String,
        remaining: Decimal,
        warningThreshold: Decimal? = nil,
        criticalThreshold: Decimal? = nil,
        windows: [QuotaWindow]? = nil,
        resetAt: Date,
        now: Date
    ) -> MockQuotaFixture {
        let account = Account(
            id: UUID(),
            provider: .moonshot,
            kind: .subscription,
            label: label,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
        let resolvedWindows = windows ?? [
            QuotaWindow(
                name: "5 小时窗口",
                limit: 100,
                remaining: 85,
                resetAt: now.addingTimeInterval(3_600)
            ),
        ]
        return MockQuotaFixture(
            account: account,
            snapshot: QuotaSnapshot(
                accountID: account.id,
                limit: 100,
                remaining: remaining,
                resetAt: resetAt,
                fetchedAt: now,
                windows: resolvedWindows
            )
        )
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
        warningThreshold: Decimal? = nil,
        criticalThreshold: Decimal? = nil
    ) -> MockFixture {
        let account = Account(
            id: UUID(),
            provider: provider,
            label: label,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
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
