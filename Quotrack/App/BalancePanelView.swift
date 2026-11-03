import Foundation
import SwiftUI

/// The floating panel's content. It depends on the BalanceMonitor seam, so
/// previews and fakes can supply any row state. Observation still tracks the
/// concrete @Observable monitor behind the existential at runtime.
@MainActor
struct BalancePanelView: View {
    let monitor: any BalanceMonitor
    var onAddAccount: () -> Void = {}
    @State private var expansion = BalanceRowExpansion()
    @State private var providerCollapse = ProviderCollapseState()

    var body: some View {
        let rows = monitor.rows
        if rows.isEmpty {
            emptyState
        } else {
            panel(rows: rows)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(UIStrings.emptyAccountsTitle, systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text(UIStrings.emptyAccountsDescription)
        } actions: {
            Button(UIStrings.addAccount, action: onAddAccount)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func panel(rows: [BalanceRow]) -> some View {
        let header = PanelHeaderPresentation.viewState(for: rows)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(header.title)
                        .font(.headline)
                    Text(header.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(header.healthyText)
                    .foregroundStyle(.green)
                if header.warningCount > 0 {
                    Text(header.warningText)
                        .foregroundStyle(.orange)
                }
                if header.criticalCount > 0 {
                    Text(header.criticalText)
                        .foregroundStyle(.red)
                }
                Text(header.errorText)
                    .foregroundStyle(.red)
                Button {
                    Task { await monitor.refresh() }
                } label: {
                    Label(UIStrings.refreshAll, systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(UIStrings.refreshAll)
                .accessibilityLabel(UIStrings.refreshAll)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(
                        ProviderGroupPresentation.groups(
                            from: rows,
                            collapseState: providerCollapse
                        )
                    ) { group in
                        ProviderCardView(
                            group: group,
                            isRowExpanded: { expansion.isExpanded($0) },
                            onToggleRow: { expansion.toggle($0) },
                            onToggleCollapse: {
                                providerCollapse.toggle(group.provider)
                            },
                            onRefreshProvider: {
                                await monitor.refresh(provider: group.provider)
                            },
                            onRefreshAccount: {
                                await monitor.refresh(accountID: $0)
                            }
                        )
                        Divider()
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// One Provider card. The header is always visible; collapsing swaps the
/// Account rows for a per-Kind summary line without changing the underlying
/// row states.
@MainActor
private struct ProviderCardView: View {
    let group: ProviderGroupViewState
    let isRowExpanded: (Account.ID) -> Bool
    let onToggleRow: (Account.ID) -> Void
    let onToggleCollapse: () -> Void
    let onRefreshProvider: @MainActor () async -> Void
    let onRefreshAccount: @MainActor (Account.ID) async -> Void

    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if group.isCollapsed {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.sections) { section in
                        ProviderKindSummaryView(section: section)
                    }
                }
                .padding(.leading, 26)
                .padding(.trailing, 14)
                .padding(.bottom, 8)
            } else {
                ForEach(group.sections) { section in
                    sectionView(section)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onToggleCollapse) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(group.isCollapsed ? 0 : 90))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(group.name)
                                .font(.headline)
                            ProviderHealthBadge(
                                health: group.health,
                                text: group.healthText
                            )
                            if group.errorCount > 0 {
                                ProviderCountBadge(
                                    text: group.errorText,
                                    color: .red
                                )
                            }
                            if group.staleCount > 0 {
                                ProviderCountBadge(
                                    text: group.staleText,
                                    color: .secondary
                                )
                            }
                        }
                        Text(group.kindCountText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(
                group.isCollapsed
                    ? UIStrings.expandProviderHint
                    : UIStrings.collapseProviderHint
            )

            Button {
                isRefreshing = true
                Task {
                    await onRefreshProvider()
                    isRefreshing = false
                }
            } label: {
                Label(UIStrings.providerRefresh, systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(isRefreshing)
            .help(UIStrings.providerRefresh)
            .accessibilityLabel(UIStrings.providerRefresh)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func sectionView(_ section: ProviderKindSectionViewState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ProviderKindSectionHeader(section: section)
            ForEach(section.rows) { row in
                BalanceRowView(
                    account: row.account,
                    viewState: BalanceRowPresentation.viewState(
                        for: row,
                        now: Date()
                    ),
                    detail: BalanceRowPresentation.detailViewState(for: row),
                    isExpanded: isRowExpanded(row.id),
                    showsProviderName: false,
                    onToggle: { onToggleRow(row.id) },
                    onRefresh: { await onRefreshAccount(row.id) }
                )
                .padding(.horizontal, 14)
                Divider()
                    .padding(.leading, 18)
            }
        }
    }
}

/// The expanded section title. Health and the per-Kind totals sit on the
/// header so a section stays scannable without opening an Account row.
private struct ProviderKindSectionHeader: View {
    let section: ProviderKindSectionViewState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                Text(UIStrings.providerAccountCount(section.accountCount))
                    .foregroundStyle(.secondary)
                if section.warningCount > 0 {
                    Text(UIStrings.providerWarningCount(section.warningCount))
                        .foregroundStyle(.orange)
                }
                if section.criticalCount > 0 {
                    Text(UIStrings.providerCriticalCount(section.criticalCount))
                        .foregroundStyle(.red)
                }
                if section.errorCount > 0 {
                    Text(UIStrings.providerErrorCount(section.errorCount))
                        .foregroundStyle(.red)
                }
                if section.staleCount > 0 {
                    Text(UIStrings.providerStaleCount(section.staleCount))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                ProviderHealthBadge(
                    health: section.health,
                    text: section.healthText
                )
            }
            .font(.caption)

            if section.kind == .balance, let total = section.balanceTotalText {
                Text(total)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if let worst = section.quotaWorstRemainingSummaryText {
                Text(worst)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.leading, 26)
        .padding(.trailing, 14)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

/// The per-Kind line shown while a Provider card is collapsed.
private struct ProviderKindSummaryView: View {
    let section: ProviderKindSectionViewState

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(section.title)
                    .font(.caption.weight(.semibold))
                Text(UIStrings.providerAccountCount(section.accountCount))
                    .foregroundStyle(.secondary)
                if section.errorCount > 0 {
                    Text(UIStrings.providerErrorCount(section.errorCount))
                        .foregroundStyle(.red)
                }
                if section.staleCount > 0 {
                    Text(UIStrings.providerStaleCount(section.staleCount))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                ProviderHealthBadge(
                    health: section.health,
                    text: section.healthText
                )
            }
            .font(.caption)

            if section.kind == .balance, let total = section.balanceTotalText {
                Text(total)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if let worst = section.quotaWorstRemainingSummaryText {
                Text(worst)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

private struct ProviderHealthBadge: View {
    let health: AccountHealth
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(health.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(health.color.opacity(0.12), in: Capsule())
    }
}

private struct ProviderCountBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.10), in: Capsule())
    }
}

@MainActor
private struct BalanceRowView: View {
    let account: Account
    let viewState: BalanceRowViewState
    let detail: BalanceRowDetailViewState
    let isExpanded: Bool
    /// False inside a Provider card, where the card header already names the
    /// Provider. The standalone row previews keep the Provider name.
    var showsProviderName: Bool = true
    let onToggle: () -> Void
    let onRefresh: @MainActor () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if showsProviderName {
                                Text(viewState.providerName)
                                    .font(.headline)
                            }
                            if viewState.showsHealth {
                                Text(viewState.healthText)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(viewState.health.color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        viewState.health.color.opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                            if viewState.isExperimental {
                                Text(UIStrings.experimentalBadge)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                .secondary.opacity(0.35)
                                            )
                                    )
                            }
                        }
                        Text(viewState.label)
                            .font(showsProviderName ? .subheadline : .headline)
                            .foregroundStyle(showsProviderName ? .secondary : .primary)
                        if !viewState.isQuota {
                            BalanceThresholdGauge(
                                account: account,
                                health: viewState.health
                            )
                        }
                        Text(viewState.thresholdText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if viewState.isQuota,
                           let ratio = viewState.quotaRemainingRatio {
                            ProgressView(value: ratio)
                                .tint(balanceColor)
                                .controlSize(.small)
                        }
                        if let secondary = viewState.quotaSecondaryText {
                            Text(secondary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 2) {
                        if viewState.isQuota {
                            Text(viewState.quotaRemainingText ?? "—")
                                .font(.title3)
                                .monospacedDigit()
                                .foregroundStyle(balanceColor)
                            if let used = viewState.quotaUsedText {
                                Text(used)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let reset = viewState.quotaResetText {
                                Text(reset)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(viewState.balanceText)
                                .font(.title3)
                                .monospacedDigit()
                                .foregroundStyle(balanceColor)
                        }
                        HStack(spacing: 4) {
                            Text(viewState.updatedText)
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(viewState.statusText)
                                .foregroundStyle(statusColor)
                        }
                        .font(.caption)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(isExpanded ? UIStrings.collapseRowHint : UIStrings.expandRowHint)

            if isExpanded {
                BalanceRowDetailView(detail: detail, onRefresh: onRefresh)
                    .padding(.leading, 18)
                    .padding(.bottom, 10)
            }
        }
    }

    private var appearance: BalanceRowAppearance {
        viewState.tone.appearance
    }

    private var statusColor: Color {
        appearance.status.color
    }

    private var balanceColor: Color {
        appearance.balance.color
    }
}

private extension AccountHealth {
    var emphasis: BalanceRowAppearance.Emphasis {
        switch self {
        case .normal: .positive
        case .warning: .warning
        case .critical: .error
        case .unset: .secondary
        }
    }

    var color: Color { emphasis.color }
}

private extension ThresholdGaugeSegment.Role {
    var emphasis: BalanceRowAppearance.Emphasis {
        switch self {
        case .critical: .error
        case .warning: .warning
        case .normal: .positive
        }
    }
}

private struct BalanceThresholdGauge: View {
    let account: Account
    let health: AccountHealth

    var body: some View {
        let segments = ThresholdGaugePresentation.segments(
            for: account,
            health: health
        )
        if !segments.isEmpty {
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            segment.role.emphasis.color.opacity(
                                segment.isActive ? 1 : 0.22
                            )
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 4)
            .clipShape(Capsule())
            .accessibilityLabel(
                "\(UIStrings.healthThresholdsTitle)：\(health.displayText)"
            )
        }
    }
}

private extension BalanceRowAppearance.Emphasis {
    var color: Color {
        switch self {
        case .primary: .primary
        case .positive: .green
        case .warning: .orange
        case .muted: .gray
        case .secondary: .secondary
        case .error: .red
        case .pending: .secondary
        }
    }
}

@MainActor
private struct BalanceRowDetailView: View {
    let detail: BalanceRowDetailViewState
    let onRefresh: @MainActor () async -> Void
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let balanceText = detail.balanceText {
                labelledValue(UIStrings.preciseBalanceLabel, balanceText)
            }
            if let fetchedAtText = detail.fetchedAtText {
                labelledValue(UIStrings.fetchedAtLabel, fetchedAtText)
            }
            labelledValue(UIStrings.healthLabel, detail.healthText)
            labelledValue(UIStrings.thresholdLabel, detail.thresholdText)
            if !detail.quotaLines.isEmpty {
                Text(UIStrings.quotaDetailTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(detail.quotaLines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            if let currencyWarningText = detail.currencyWarningText {
                Text(currencyWarningText)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !detail.breakdown.isEmpty {
                Text(UIStrings.breakdownTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(detail.breakdown) { item in
                    HStack(spacing: 8) {
                        Text(item.label)
                        Spacer(minLength: 8)
                        Text(item.amountText)
                            .monospacedDigit()
                    }
                    .font(.caption)
                }
            }
            if let errorText = detail.errorText {
                Text(UIStrings.errorTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                isRefreshing = true
                Task {
                    await onRefresh()
                    isRefreshing = false
                }
            } label: {
                Label(
                    isRefreshing ? UIStrings.refreshing : UIStrings.refreshAccount,
                    systemImage: "arrow.clockwise"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labelledValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

#Preview("模拟数据面板") {
    let monitor = LiveBalanceMonitor(dataSource: .mock(now: Date()))
    BalancePanelView(monitor: monitor)
        .frame(width: 360, height: 420)
        .task { await monitor.refresh() }
}

#Preview("空状态") {
    BalancePanelView(monitor: PreviewBalanceMonitor())
        .frame(width: 360, height: 420)
}

#Preview("新鲜、过期与错误") {
    let now = Date()
    let freshAccount = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
    let staleAccount = Account(id: UUID(), provider: .moonshot, label: "Kimi 主账号")
    let errorAccount = Account(id: UUID(), provider: .openRouter, label: "OpenRouter 管理")
    let rows = [
        BalanceRow(
            account: freshAccount,
            snapshot: .balance(
                BalanceSnapshot(
                    accountID: freshAccount.id,
                    balance: Balance(amount: Decimal(string: "128.40")!, currency: .cny),
                    fetchedAt: now.addingTimeInterval(-120),
                    isAvailable: true
                )
            ),
            status: .fresh
        ),
        BalanceRow(
            account: staleAccount,
            snapshot: .balance(
                BalanceSnapshot(
                    accountID: staleAccount.id,
                    balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
                    fetchedAt: now.addingTimeInterval(-1_200),
                    isAvailable: true
                )
            ),
            status: .stale
        ),
        BalanceRow(
            account: errorAccount,
            snapshot: nil,
            status: .error,
            error: .permission
        ),
    ]
    BalancePanelView(monitor: PreviewBalanceMonitor(rows: rows))
        .frame(width: 360, height: 420)
}

#Preview("健康状态") {
    let now = Date()
    let normalAccount = Account(
        id: UUID(),
        provider: .deepSeek,
        currency: .cny,
        label: "正常",
        warningThreshold: 10,
        criticalThreshold: 5
    )
    let warningAccount = Account(
        id: UUID(),
        provider: .moonshot,
        currency: .cny,
        label: "预警",
        warningThreshold: 10,
        criticalThreshold: 5
    )
    let criticalAccount = Account(
        id: UUID(),
        provider: .openRouter,
        currency: .usd,
        label: "紧急",
        warningThreshold: 10,
        criticalThreshold: 5
    )
    let unsetAccount = Account(
        id: UUID(),
        provider: .deepSeek,
        currency: .cny,
        label: "未设置"
    )
    let rows = [
        BalanceRow(
            account: normalAccount,
            snapshot: .balance(
                BalanceSnapshot(
                    accountID: normalAccount.id,
                    balance: Balance(amount: 20, currency: .cny),
                    fetchedAt: now,
                    isAvailable: true
                )
            ),
            status: .fresh
        ),
        BalanceRow(
            account: warningAccount,
            snapshot: .balance(
                BalanceSnapshot(
                    accountID: warningAccount.id,
                    balance: Balance(amount: 7, currency: .cny),
                    fetchedAt: now,
                    isAvailable: true
                )
            ),
            status: .fresh
        ),
        BalanceRow(
            account: criticalAccount,
            snapshot: .balance(
                BalanceSnapshot(
                    accountID: criticalAccount.id,
                    balance: Balance(amount: 4, currency: .usd),
                    fetchedAt: now,
                    isAvailable: true
                )
            ),
            status: .fresh
        ),
        BalanceRow(
            account: unsetAccount,
            snapshot: .balance(
                BalanceSnapshot(
                    accountID: unsetAccount.id,
                    balance: Balance(amount: 20, currency: .cny),
                    fetchedAt: now,
                    isAvailable: true
                )
            ),
            status: .fresh
        ),
    ]
    BalancePanelView(monitor: PreviewBalanceMonitor(rows: rows))
        .frame(width: 360, height: 520)
}

#Preview("Kimi Code 订阅") {
    BalancePanelView(monitor: PreviewBalanceMonitor(rows: makeKimiQuotaRows(now: Date())))
        .frame(width: 360, height: 520)
}

private func makeKimiQuotaRows(now: Date) -> [BalanceRow] {
    func quotaRow(
        label: String,
        region: Region,
        remaining: Decimal,
        warning: Decimal?,
        critical: Decimal?
    ) -> BalanceRow {
        let account = Account(
            id: UUID(),
            provider: .moonshot,
            region: region,
            kind: .subscription,
            label: label,
            warningThreshold: warning,
            criticalThreshold: critical
        )
        let quota = QuotaSnapshot(
            accountID: account.id,
            limit: 100,
            remaining: remaining,
            resetAt: now.addingTimeInterval(86_400),
            fetchedAt: now,
            windows: [
                QuotaWindow(
                    name: "5 小时窗口",
                    limit: 100,
                    remaining: min(100, remaining + 45),
                    resetAt: now.addingTimeInterval(3_600)
                ),
            ]
        )
        return BalanceRow(
            account: account,
            snapshot: .quota(quota),
            status: .fresh
        )
    }
    return [
        quotaRow(label: "国内 · 余量正常", region: .domestic, remaining: 80, warning: 20, critical: 10),
        quotaRow(label: "国际 · 余量预警", region: .international, remaining: 15, warning: 20, critical: 10),
        quotaRow(label: "国内 · 余量紧急", region: .domestic, remaining: 5, warning: 20, critical: 10),
        quotaRow(label: "国际 · 未设置阈值", region: .international, remaining: 60, warning: nil, critical: nil),
    ]
}

#Preview("展开详情") {
    let now = Date()
    let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
    let snapshot = BalanceSnapshot(
        accountID: account.id,
        balance: Balance(amount: Decimal(string: "128.456789")!, currency: .cny),
        fetchedAt: now,
        isAvailable: true,
        breakdown: [
            BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "28.456789")!),
            BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "100")!),
        ]
    )
    let row = BalanceRow(account: account, snapshot: .balance(snapshot), status: .fresh)
    BalanceRowView(
        account: account,
        viewState: BalanceRowPresentation.viewState(for: row, now: now),
        detail: BalanceRowPresentation.detailViewState(for: row),
        isExpanded: true,
        onToggle: {},
        onRefresh: {}
    )
    .padding()
    .frame(width: 360)
}

#Preview("错误详情") {
    let account = Account(id: UUID(), provider: .openRouter, label: "OpenRouter 管理")
    let row = BalanceRow(account: account, snapshot: nil, status: .error, error: .permission)
    BalanceRowView(
        account: account,
        viewState: BalanceRowPresentation.viewState(for: row, now: Date()),
        detail: BalanceRowPresentation.detailViewState(for: row),
        isExpanded: true,
        onToggle: {},
        onRefresh: {}
    )
    .padding()
    .frame(width: 360)
}

#Preview("单账户厂商") {
    let now = Date()
    let row = previewBalanceRow(
        provider: .deepSeek,
        label: "个人账户",
        amount: Decimal(string: "88.00")!,
        warning: 20,
        critical: 10,
        now: now
    )
    BalancePanelView(monitor: PreviewBalanceMonitor(rows: [row]))
        .frame(width: 360, height: 280)
}

#Preview("多账户厂商") {
    let now = Date()
    let rows = [
        previewBalanceRow(
            provider: .deepSeek,
            label: "个人账户",
            amount: Decimal(string: "88.00")!,
            warning: 20,
            critical: 10,
            now: now
        ),
        previewBalanceRow(
            provider: .deepSeek,
            label: "工作账户",
            amount: Decimal(string: "12.00")!,
            warning: 20,
            critical: 10,
            now: now
        ),
    ]
    BalancePanelView(monitor: PreviewBalanceMonitor(rows: rows))
        .frame(width: 360, height: 520)
}

#Preview("混合账户类型（Moonshot）") {
    let now = Date()
    let rows = makeMixedKindPreviewRows(now: now)
    BalancePanelView(monitor: PreviewBalanceMonitor(rows: rows))
        .frame(width: 360, height: 640)
}

#Preview("折叠的厂商摘要") {
    let now = Date()
    let collapse = {
        var state = ProviderCollapseState()
        state.toggle(.moonshot)
        return state
    }()
    let group = ProviderGroupPresentation.groups(
        from: makeMixedKindPreviewRows(now: now),
        collapseState: collapse
    )[0]
    ProviderCardView(
        group: group,
        isRowExpanded: { _ in false },
        onToggleRow: { _ in },
        onToggleCollapse: {},
        onRefreshProvider: {},
        onRefreshAccount: { _ in }
    )
    .padding(.vertical, 8)
    .frame(width: 360)
    .background(Color(nsColor: .windowBackgroundColor))
}

private func makeMixedKindPreviewRows(now: Date) -> [BalanceRow] {
    [
        previewBalanceRow(
            provider: .moonshot,
            label: "开放平台 · 国内",
            currency: .cny,
            amount: Decimal(string: "128.40")!,
            warning: 50,
            critical: 20,
            region: .domestic,
            now: now
        ),
        previewBalanceRow(
            provider: .moonshot,
            label: "开放平台 · 国际",
            currency: .usd,
            amount: Decimal(string: "30.00")!,
            warning: 20,
            critical: 5,
            region: .international,
            now: now
        ),
        previewQuotaRow(
            label: "Kimi Code · 国内",
            remaining: 15,
            warning: 20,
            critical: 10,
            region: .domestic,
            now: now
        ),
        previewQuotaRow(
            label: "Kimi Code · 国际",
            limit: 200,
            remaining: 80,
            warning: 20,
            critical: 10,
            region: .international,
            now: now
        ),
    ]
}

private func previewBalanceRow(
    provider: Provider,
    label: String,
    currency: Currency = .cny,
    amount: Decimal,
    warning: Decimal? = nil,
    critical: Decimal? = nil,
    region: Region? = nil,
    now: Date
) -> BalanceRow {
    let account = Account(
        id: UUID(),
        provider: provider,
        region: region,
        currency: currency,
        label: label,
        warningThreshold: warning,
        criticalThreshold: critical
    )
    return BalanceRow(
        account: account,
        snapshot: .balance(
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: amount, currency: currency),
                fetchedAt: now.addingTimeInterval(-90),
                isAvailable: true
            )
        ),
        status: .fresh
    )
}

private func previewQuotaRow(
    label: String,
    limit: Decimal = 100,
    remaining: Decimal,
    warning: Decimal? = nil,
    critical: Decimal? = nil,
    region: Region? = .domestic,
    now: Date
) -> BalanceRow {
    let account = Account(
        id: UUID(),
        provider: .moonshot,
        region: region,
        kind: .subscription,
        label: label,
        warningThreshold: warning,
        criticalThreshold: critical
    )
    return BalanceRow(
        account: account,
        snapshot: .quota(
            QuotaSnapshot(
                accountID: account.id,
                limit: limit,
                remaining: remaining,
                resetAt: now.addingTimeInterval(86_400),
                fetchedAt: now.addingTimeInterval(-60),
                windows: [
                    QuotaWindow(
                        name: "5 小时窗口",
                        limit: 100,
                        remaining: min(Decimal(100), remaining + 40),
                        resetAt: now.addingTimeInterval(3_600)
                    ),
                ]
            )
        ),
        status: .fresh
    )
}
