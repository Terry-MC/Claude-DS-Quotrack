/// Simplified Chinese UI text. New panel strings live here so a future
/// localization pass has one place to start without touching existing text.
enum UIStrings {
    // Breakdown labels
    static let breakdownGranted = "赠送余额"
    static let breakdownToppedUp = "充值余额"
    static let breakdownVoucher = "代金券余额"
    static let breakdownCash = "现金余额"
    static let breakdownTotalCredits = "总额度"
    static let breakdownUsage = "已使用"

    // Typed error detail
    static let authenticationError = "认证失败，请检查 API 密钥。"
    static let permissionError = "权限不足，请检查密钥权限。"
    static let openRouterManagementKeyError = "权限不足，OpenRouter 需要管理密钥。"
    static let networkError = "网络错误，请检查网络连接。"
    static let rateLimitError = "请求过于频繁，请稍后重试。"
    static let malformedResponseError = "响应格式异常，无法解析。"
    static let unknownError = "未知错误，请稍后重试。"

    // Expanded row
    static let preciseBalanceLabel = "精确余额"
    static let fetchedAtLabel = "获取时间"
    static let breakdownTitle = "余额构成"
    static let errorTitle = "错误详情"
    static let refreshAccount = "刷新此账户"
    static let refreshing = "刷新中…"
    static let expandRowHint = "展开详情"
    static let collapseRowHint = "收起详情"
}
