/// Simplified Chinese UI text. New panel strings live here so a future
/// localization pass has one place to start without touching existing text.
enum UIStrings {
    // Menu bar aggregate state
    static let menuBarNormalDescription = "Quotrack：一切正常"
    static let menuBarWarningDescription = "Quotrack：有账户余额偏低或数据已过期"
    static let menuBarErrorDescription = "Quotrack：有账户出错"

    // Breakdown labels
    static let breakdownGranted = "赠送余额"
    static let breakdownToppedUp = "充值余额"
    static let breakdownVoucher = "代金券余额"
    static let breakdownCash = "现金余额"
    static let breakdownTotalCredits = "总额度"
    static let breakdownUsage = "已使用"

    // Typed error detail
    static let authenticationError = "认证失败，请检查 API 密钥。"
    static let moonshotAuthenticationError = "认证失败，请检查 API 密钥，并确认所选区域与凭证匹配。"
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

    // Empty panel
    static let emptyAccountsTitle = "还没有账户"
    static let emptyAccountsDescription = "添加一个账户以开始监控余额。"
    static let addAccount = "添加账户…"

    // Settings
    static let settingsAccountsTitle = "账户"
    static let settingsPollingTitle = "轮询"
    static let pollingIntervalLabel = "轮询间隔"
    static let minutesUnit = "分钟"
    static let pollingIntervalHint = "自动刷新余额的时间间隔，范围为 1 到 60 分钟。"
    static let settingsLaunchAtLoginTitle = "启动"
    static let launchAtLoginLabel = "开机时启动 Quotrack"
    static let launchAtLoginMenu = "开机启动"
    static let launchAtLoginHint = "默认关闭。开启后 Quotrack 会在登录时自动启动。"
    static let launchAtLoginRequiresApproval = "已请求开机启动，请在“系统设置 › 通用 › 登录项”中允许 Quotrack。"
    static let openLoginItemsSettings = "打开系统设置"
    static let settingsUnsupportedTitle = "不支持的厂商"
    static let unsupportedProvidersExplanation = """
    OpenAI、Anthropic、Gemini 和 Mistral 不提供个人账户余额 API，只能查询消耗或配额，因此 Quotrack v1 不会显示这些厂商。余额与消耗、配额是不同指标，混在一起会误导用户。详见 ADR-0001。
    """
    static let lowBalanceWarningTitle = "低余额提醒"
    static let lowBalanceWarningToggle = "启用低余额提醒"
    static let lowBalanceThresholdLabel = "阈值"
    static let lowBalanceThresholdHint = "余额低于该值时，面板会显示警告（默认关闭）。"
    static let lowBalanceThresholdSaved = "低余额提醒"
    static let invalidThreshold = "低余额阈值必须大于 0。"

    // Onboarding
    static let onboardingTitle = "欢迎使用 Quotrack"
    static let onboardingProviderTitle = "选择厂商"
    static let onboardingProviderHint = "仅支持提供个人账户余额 API 的厂商。"
    static let onboardingRegionTitle = "选择区域"
    static let onboardingRegionHint = "凭证只在所选区域内有效。"
    static let onboardingDetailsTitle = "账户信息"
    static let onboardingLabelField = "标签"
    static let onboardingCredentialField = "API 密钥"
    static let onboardingNext = "下一步"
    static let onboardingBack = "上一步"
    static let onboardingTestAndSave = "测试连接并保存"
    static let onboardingTesting = "正在测试连接…"
    static let onboardingSuccess = "连接成功，账户已保存。"
    static let onboardingDone = "完成"
    static let onboardingCredentialHint = "凭证只存储在 macOS 钥匙串中，保存后不会再次显示。"
}
