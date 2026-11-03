/// Simplified Chinese UI text. New panel strings live here so a future
/// localization pass has one place to start without touching existing text.
enum UIStrings {
    // App identity
    static let displayName = "Quotrack"
    static let displaySubtitle = "AI 余额监控"

    // Menu bar aggregate state
    static let menuBarNormalDescription = "Quotrack：一切正常"
    static let menuBarWarningDescription = "Quotrack：有账户需要关注"
    static let menuBarCriticalDescription = "Quotrack：有账户需要立即处理"
    static let menuBarErrorDescription = "Quotrack：有账户出错"

    // Breakdown labels
    static let breakdownGranted = "赠送余额"
    static let breakdownToppedUp = "充值余额"
    static let breakdownVoucher = "代金券余额"
    static let breakdownCash = "现金余额"
    static let breakdownTotalCredits = "总额"
    static let breakdownSpend = "消费"

    // Typed error detail
    static let authenticationError = "认证失败，请检查 API 密钥。"
    static let regionAuthenticationError = "认证失败，请检查 API 密钥，并确认所选区域与凭证匹配。"
    static let kimiCodeAuthenticationError = "Kimi Code 认证失败：请确认密钥来自 Kimi Code Console（sk-kimi-…），并选择与账号一致的国内/国际区域。"
    static let kimiCodeCredentialRequired = "Kimi Code 订阅需要以 sk-kimi 开头的 Kimi Code API key；当前 sk-… 密钥不是订阅密钥。若它是 Moonshot 开放平台密钥，请改用“充值”账户类型。"
    static let permissionError = "权限不足，请检查密钥权限。"
    static let openRouterManagementKeyError = "权限不足，OpenRouter 需要管理密钥。"
    static let networkError = "网络错误，请检查网络连接。"
    static let rateLimitError = "请求过于频繁，请稍后重试。"
    static let malformedResponseError = "响应格式异常，无法解析。"
    static let unsupportedAccountKindError = "该账户类型暂不支持。"
    static let unknownError = "未知错误，请稍后重试。"
    static func unknownErrorWithStatus(_ statusCode: Int) -> String {
        "未知错误（HTTP \(statusCode)），请稍后重试。"
    }

    // Health and thresholds
    static let healthNormal = "正常"
    static let healthWarning = "预警"
    static let healthCritical = "紧急"
    static let healthUnset = "未设置"
    static let thresholdUnset = "未设置阈值"
    static let warningThresholdShort = "预警"
    static let criticalThresholdShort = "紧急"
    static let warningThresholdLabel = "预警线"
    static let criticalThresholdLabel = "紧急线"
    static let healthThresholdsTitle = "健康阈值"
    static let healthThresholdsHint = "留空表示不设置。余额低于或等于预警线时显示“预警”，低于或等于紧急线时显示“紧急”。"
    static let healthThresholdsPercentHint = "留空表示不设置。剩余额度低于或等于预警线时显示“预警”，低于或等于紧急线时显示“紧急”。"
    static let thresholdCurrencyHint = "金额按连接测试返回的币种保存。"
    static let warningThresholdPercentLabel = "余量预警线（%）"
    static let criticalThresholdPercentLabel = "余量紧急线（%）"
    static let healthLabel = "健康"
    static let thresholdLabel = "阈值"
    static let quotaDetailTitle = "额度"

    static func currencyMismatchWarning(
        thresholdCurrency: String,
        balanceCurrency: String
    ) -> String {
        "阈值币种为 \(thresholdCurrency)，当前余额为 \(balanceCurrency)，健康状态未计算。"
    }
    static let accountKindLabel = "账户类型"
    static let statusFresh = "已更新"
    /// The row state for a persisted Account whose Provider was dropped.
    static let unsupportedProviderState = "不再支持"

    // Provider cards and grouped sections
    static let providerBalanceSectionTitle = "充值"
    static let providerQuotaSectionTitle = "订阅"
    static let providerBalanceTotalLabel = "合计"
    static let providerRefresh = "刷新此厂商"
    static let expandProviderHint = "展开厂商"
    static let collapseProviderHint = "收起厂商"
    static func providerQuotaWorstRemaining(_ percentText: String) -> String {
        "最低剩余 \(percentText)"
    }
    static func providerAccountCount(_ count: Int) -> String {
        "\(count) 个账户"
    }
    static func providerKindCount(_ kind: AccountKind, _ count: Int) -> String {
        "\(kind.displayName) \(count)"
    }
    static func providerWarningCount(_ count: Int) -> String {
        "\(healthWarning) \(count)"
    }
    static func providerCriticalCount(_ count: Int) -> String {
        "\(healthCritical) \(count)"
    }
    static func providerErrorCount(_ count: Int) -> String {
        "错误 \(count)"
    }
    static func providerStaleCount(_ count: Int) -> String {
        "已过期 \(count)"
    }

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
    static let refreshAll = "全部刷新"

    // Health transition notifications and the in-app toast fallback
    static let healthNotificationTitle = "Quotrack 健康提醒"
    static let healthRecoveryNotificationTitle = "Quotrack 健康恢复"
    static let notificationOpenHint = "点击打开面板并聚焦相关账户。"
    static let dismissNotificationToast = "关闭提醒"
    static func healthNotificationSummary(count: Int) -> String {
        "\(count) 个账户健康状态变化"
    }

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
    static let settingsUnsupportedTitle = "厂商支持说明"
    static let unsupportedProvidersExplanation = """
    Quotrack 支持个人余额 API，也支持 Moonshot 的 Kimi Code 订阅额度（实验性）。SiliconFlow 的个人余额接口已停止服务，已有账户会显示为“不再支持”，不会轮询，可以删除。OpenAI、Anthropic、Gemini 和 Mistral 不提供个人账户余额 API，只能查询消耗或配额，因此不会出现在可添加厂商中。余额、消耗、额度是不同指标，详见 ADR-0001 与 ADR-0002。
    """
    static let settingsDeferredIntegrationsExplanation = """
    WorkBuddy、Claude Pro/Max、ChatGPT/Codex、Gemini CLI 和 SuperGrok 需要读取桌面应用或 CLI 的 OAuth 登录状态，v2 暂不支持。Quotrack 不会读取浏览器 Cookie、桌面容器或 CLI 凭证；相关本地桥接计划见 ADR-0002。
    """
    static let invalidThreshold = "阈值无效：请检查数值范围，并确保紧急线低于预警线。"
    static let deleteAccountConfirmation = "该账户的钥匙串凭证和已保存的余额/额度快照都会被移除。"

    // Onboarding
    static let onboardingTitle = "欢迎使用 Quotrack"
    static let onboardingProviderTitle = "选择厂商"
    static let onboardingProviderHint = "支持个人余额 API，以及 Moonshot 的 Kimi Code 订阅额度（实验性）。"
    static let onboardingRegionTitle = "选择区域"
    static let onboardingRegionHint = "凭证只在所选区域内有效。"
    static let onboardingDetailsTitle = "账户信息"
    static let onboardingLabelField = "标签"
    static let onboardingCredentialField = "API 密钥"
    static let openRouterManagementKeyWarning = "OpenRouter 只能使用管理密钥，普通推理密钥无法查询余额。管理密钥权限更高，请妥善保管。"
    static let kimiCodeCredentialWarning = "Kimi Code 订阅账户使用 sk-kimi-… 密钥，不是 Moonshot 开放平台密钥。"
    static let experimentalBadge = "实验性"
    static let onboardingNext = "下一步"
    static let onboardingBack = "上一步"
    static let onboardingTestAndSave = "测试连接并保存"
    static let onboardingTesting = "正在测试连接…"
    static let onboardingSuccess = "连接成功，账户已保存。"
    static let onboardingDone = "完成"
    static let onboardingCredentialHint = "凭证只存储在 macOS 钥匙串中，保存后不会再次显示。"

    // Dock
    static let dockNormalDescription = "Quotrack：一切正常"
    static let dockOpenPanelHint = "打开 Quotrack 主面板"

    static func dockWarningDescription(count: Int) -> String {
        "Quotrack：\(count) 个账户需要关注"
    }

    static func dockCriticalDescription(count: Int) -> String {
        "Quotrack：\(count) 个账户需要立即处理"
    }
}
