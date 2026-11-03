import Foundation
import SwiftUI

/// The floating panel's content. It depends on the BalanceMonitor seam, so
/// previews and fakes can supply any row state. Observation still tracks the
/// concrete @Observable monitor behind the existential at runtime.
@MainActor
struct BalancePanelView: View {
    let monitor: any BalanceMonitor
    /// Set by the panel controller when a notification or toast is clicked.
    /// Requests carry a sequence so repeated focus on one Account still
    /// scrolls the panel back to it.
    var focus: PanelFocusModel = PanelFocusModel()
    var onAddAccount: (Provider?) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    var onClose: () -> Void = {}
    @State private var expansion = BalanceRowExpansion()
    @State private var providerCollapse = ProviderCollapseState()

    var body: some View {
        ZStack {
            GlassPanelBackground()
            if monitor.rows.isEmpty {
                emptyState
            } else {
                panel(rows: monitor.rows)
            }
        }
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        .clipShape(
            RoundedRectangle(cornerRadius: UITheme.Radius.panel, style: .continuous)
        )
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    UITheme.accentGradient,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: UITheme.accentEnd.opacity(0.35), radius: 16, y: 8)
            VStack(spacing: 4) {
                Text(UIStrings.emptyAccountsTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UITheme.textPrimary)
                Text(UIStrings.emptyAccountsDescription)
                    .font(.system(size: 11.5))
                    .foregroundStyle(UITheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button(UIStrings.addAccount) {
                onAddAccount(nil)
            }
                .buttonStyle(AccentButtonStyle())
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private func panel(rows: [BalanceRow]) -> some View {
        let header = PanelHeaderPresentation.viewState(for: rows)
        let groups = ProviderGroupPresentation.groups(
            from: rows,
            collapseState: providerCollapse
        )
        return VStack(alignment: .leading, spacing: 0) {
            panelHeader(header)
            Rectangle()
                .fill(UITheme.hairline)
                .frame(height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: UITheme.Spacing.card) {
                        ForEach(groups) { group in
                            ProviderCardView(
                                group: group,
                                isRowExpanded: { expansion.isExpanded($0) },
                                onToggleRow: { expansion.toggle($0) },
                                onToggleCollapse: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        providerCollapse.toggle(group.provider)
                                    }
                                },
                                onAddAccount: { provider in
                                    onAddAccount(provider)
                                },
                                onRefreshProvider: {
                                    await monitor.refresh(provider: group.provider)
                                },
                                onRefreshAccount: {
                                    await monitor.refresh(accountID: $0)
                                }
                            )
                            .id(group.provider)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.never)
                .onChange(of: focus.request) { _, request in
                    reveal(request, rows: rows, using: proxy)
                }
                .onAppear {
                    if focus.request == nil, let first = groups.first {
                        proxy.scrollTo(first.provider, anchor: .top)
                    } else {
                        reveal(focus.request, rows: rows, using: proxy)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func panelHeader(_ header: PanelHeaderViewState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(header.title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(0.2)
                    .foregroundStyle(UITheme.textPrimary)
                Text(header.subtitle)
                    .font(.system(size: 10.5))
                    .tracking(0.4)
                    .foregroundStyle(UITheme.textTertiary)

                HStack(spacing: 10) {
                    HeaderCount(
                        text: header.healthyText,
                        color: UITheme.green,
                        count: header.healthyCount
                    )
                    if header.warningCount > 0 {
                        HeaderCount(
                            text: header.warningText,
                            color: UITheme.yellow,
                            count: header.warningCount
                        )
                    }
                    if header.criticalCount > 0 {
                        HeaderCount(
                            text: header.criticalText,
                            color: UITheme.red,
                            count: header.criticalCount
                        )
                    }
                    HeaderCount(
                        text: header.errorText,
                        color: UITheme.red.opacity(0.8),
                        count: header.errorCount
                    )
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                GlassIconButton(
                    systemName: "gearshape",
                    help: "设置"
                ) {
                    onOpenSettings()
                }
                GlassIconButton(
                    systemName: "arrow.clockwise",
                    help: UIStrings.refreshAll
                ) {
                    Task { await monitor.refresh() }
                }
                GlassIconButton(systemName: "xmark", help: "收起面板") {
                    onClose()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    /// Expands the requested row and scrolls it into view. The request is
    /// ignored once the Account is no longer in the panel.
    private func reveal(
        _ request: PanelFocusModel.Request?,
        rows: [BalanceRow],
        using proxy: ScrollViewProxy
    ) {
        guard let request,
              let row = rows.first(where: { $0.id == request.accountID }) else {
            return
        }
        // The affected Account may sit inside a collapsed Provider card, so
        // reveal the card before scrolling to the row.
        providerCollapse.expand(row.account.provider)
        expansion.expand(request.accountID)
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(request.accountID, anchor: .center)
            }
        }
    }
}

private struct HeaderCount: View {
    let text: String
    let color: Color
    let count: Int

    var body: some View {
        if count > 0 {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 4.5, height: 4.5)
                Text(text)
                    .font(.system(size: 9.5, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(color)
            }
            .accessibilityElement(children: .combine)
        }
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
    let onAddAccount: (Provider) -> Void
    let onRefreshProvider: @MainActor () async -> Void
    let onRefreshAccount: @MainActor (Account.ID) async -> Void

    @State private var isRefreshing = false
    @State private var isHovering = false

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: UITheme.Radius.card,
            style: .continuous
        )
        VStack(alignment: .leading, spacing: 0) {
            header
            if group.isCollapsed {
                collapsedSummary
            } else {
                VStack(spacing: 0) {
                    ForEach(group.sections) { section in
                        if section.id != group.sections.first?.id {
                            Rectangle()
                                .fill(UITheme.hairlineSubtle)
                                .frame(height: 1)
                                .padding(.horizontal, 14)
                        }
                        sectionView(section)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(UITheme.card, in: shape)
        .overlay(
            shape.strokeBorder(
                isHovering ? Color.white.opacity(0.16) : UITheme.hairline,
                lineWidth: 1
            )
        )
        .clipShape(shape)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onToggleCollapse) {
                HStack(spacing: 9) {
                    ProviderMark(provider: group.provider, size: 18)
                    Text(group.name)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(UITheme.textPrimary)
                        .lineLimit(1)
                    TypeTag(
                        text: group.typeTag.text,
                        style: group.typeTag.style
                    )
                    CountTag(text: UIStrings.providerAccountCount(group.accountCount))
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

            HStack(spacing: 2) {
                GlassIconButton(
                    systemName: "plus",
                    help: UIStrings.addAccount,
                    size: 22,
                    action: { onAddAccount(group.provider) }
                )
                GlassIconButton(
                    systemName: "arrow.clockwise",
                    help: UIStrings.providerRefresh,
                    size: 22,
                    isBusy: isRefreshing
                ) {
                    isRefreshing = true
                    Task {
                        await onRefreshProvider()
                        isRefreshing = false
                    }
                }
                Button(action: onToggleCollapse) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(UITheme.textTertiary)
                        .rotationEffect(.degrees(group.isCollapsed ? -90 : 0))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    group.isCollapsed
                        ? UIStrings.expandProviderHint
                        : UIStrings.collapseProviderHint
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var collapsedSummary: some View {
        VStack(spacing: 10) {
            ForEach(group.sections) { section in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        KindDot(kind: section.kind)
                        Text(
                            "\(section.title)账户 · \(UIStrings.providerAccountCount(section.accountCount))"
                        )
                        .font(.system(size: 10.5, weight: .medium))
                        .tracking(0.3)
                        .foregroundStyle(UITheme.textTertiary)
                        Spacer(minLength: 8)
                        if let summary = summary(for: section) {
                            Text(summary)
                                .font(.system(size: 10.5))
                                .monospacedDigit()
                                .foregroundStyle(UITheme.textSecondary)
                        }
                        HealthPill(
                            health: section.health,
                            text: section.healthText
                        )
                    }
                    if section.kind == .subscription,
                       let ratio = quotaRatio(for: section) {
                        ThinBar(ratio: ratio, tint: UITheme.color(for: section.health))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 12)
    }

    private func sectionView(_ section: ProviderKindSectionViewState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(section)
            Rectangle()
                .fill(UITheme.hairlineSubtle)
                .frame(height: 1)
                .padding(.leading, 14)
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
                .id(row.id)
                .padding(.horizontal, 14)
                if row.id != section.rows.last?.id {
                    Rectangle()
                        .fill(UITheme.hairlineSubtle)
                        .frame(height: 1)
                        .padding(.leading, 22)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func sectionHeader(_ section: ProviderKindSectionViewState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                KindDot(kind: section.kind)
                Text(
                    "\(section.title)账户 · \(UIStrings.providerAccountCount(section.accountCount))"
                )
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(UITheme.textTertiary)
                Spacer(minLength: 8)
                HealthPill(health: section.health, text: section.healthText)
            }

            HStack(spacing: 8) {
                if let summary = summary(for: section) {
                    Text(summary)
                        .font(.system(size: 10.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(UITheme.textSecondary)
                }
                Spacer(minLength: 8)
                issueCounts(for: section)
            }

            if section.kind == .subscription,
               let ratio = quotaRatio(for: section) {
                ThinBar(ratio: ratio, tint: UITheme.color(for: section.health))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func issueCounts(for section: ProviderKindSectionViewState) -> some View {
        HStack(spacing: 8) {
            if section.warningCount > 0 {
                IssueLabel(
                    text: UIStrings.providerWarningCount(section.warningCount),
                    color: UITheme.yellow
                )
            }
            if section.criticalCount > 0 {
                IssueLabel(
                    text: UIStrings.providerCriticalCount(section.criticalCount),
                    color: UITheme.red
                )
            }
            if section.errorCount > 0 {
                IssueLabel(
                    text: UIStrings.providerErrorCount(section.errorCount),
                    color: UITheme.red
                )
            }
            if section.staleCount > 0 {
                IssueLabel(
                    text: UIStrings.providerStaleCount(section.staleCount),
                    color: UITheme.textTertiary
                )
            }
        }
    }

    private func summary(for section: ProviderKindSectionViewState) -> String? {
        if section.kind == .balance {
            return section.balanceTotalText
        }
        return section.quotaWorstRemainingSummaryText
    }

    private func quotaRatio(for section: ProviderKindSectionViewState) -> Double? {
        guard let percent = section.quotaWorstRemainingPercent else {
            return nil
        }
        return min(1, max(0, NSDecimalNumber(decimal: percent).doubleValue / 100))
    }
}

private struct CountTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5))
            .foregroundStyle(UITheme.textTertiary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(
                Capsule().strokeBorder(UITheme.hairline, lineWidth: 1)
            )
            .lineLimit(1)
    }
}

private struct KindDot: View {
    let kind: AccountKind

    var body: some View {
        Circle()
            .fill(kind == .balance ? UITheme.topUp : UITheme.subscription)
            .frame(width: 5, height: 5)
            .accessibilityHidden(true)
    }
}

private struct IssueLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9.5))
            .foregroundStyle(color)
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

    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                Button(action: onToggle) {
                    rowContent
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(
                    isExpanded ? UIStrings.collapseRowHint : UIStrings.expandRowHint
                )

                VStack(spacing: 2) {
                    GlassIconButton(
                        systemName: "arrow.clockwise",
                        help: UIStrings.refreshAccount,
                        size: 20,
                        isBusy: isRefreshing
                    ) {
                        isRefreshing = true
                        Task {
                            await onRefresh()
                            isRefreshing = false
                        }
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(UITheme.textTertiary)
                        .frame(width: 20, height: 16)
                        .accessibilityHidden(true)
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 9)

            if isExpanded {
                BalanceRowDetailView(detail: detail, onRefresh: onRefresh)
                    .padding(.leading, 22)
                    .padding(.bottom, 10)
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                if showsProviderName {
                    Text(viewState.providerName)
                        .font(.system(size: 10))
                        .foregroundStyle(UITheme.textTertiary)
                }
                Text(viewState.label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .tracking(0.2)
                    .foregroundStyle(UITheme.textPrimary)
                    .lineLimit(1)
                TypeTag(
                    text: account.kind.typeTagText,
                    style: account.kind.typeTagStyle
                )
                if viewState.isExperimental {
                    TypeTag(text: UIStrings.experimentalBadge, style: .experimental)
                }
                Spacer(minLength: 6)
                Text(metaText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(UITheme.textTertiary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(primaryValueText)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(balanceColor)
                    .lineLimit(1)
                if let secondaryValueText {
                    Text(secondaryValueText)
                        .font(.system(size: 10))
                        .foregroundStyle(UITheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                valueChips
            }

            if viewState.isQuota {
                if let ratio = viewState.quotaRemainingRatio {
                    ThinBar(ratio: ratio, tint: balanceColor)
                }
                if let secondary = viewState.quotaSecondaryText {
                    Text(secondary)
                        .font(.system(size: 9))
                        .foregroundStyle(UITheme.textTertiary)
                        .lineLimit(1)
                }
            } else {
                BalanceThresholdGauge(
                    account: account,
                    health: viewState.health
                )
            }

            HStack(spacing: 8) {
                Text(viewState.thresholdText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(UITheme.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if viewState.showsHealth {
                    HealthPill(
                        health: viewState.health,
                        text: viewState.healthText
                    )
                } else {
                    Text(viewState.statusText)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(statusColor)
                }
            }
        }
    }

    @ViewBuilder
    private var valueChips: some View {
        if viewState.isQuota {
            if let reset = viewState.quotaResetText {
                ValueChip(label: nil, value: reset)
            }
        } else {
            ForEach(Array(detail.breakdown.prefix(2))) { item in
                ValueChip(label: item.label, value: item.amountText)
            }
        }
    }

    private var metaText: String {
        "\(viewState.updatedText) · \(viewState.statusText)"
    }

    private var primaryValueText: String {
        if viewState.isQuota {
            return viewState.quotaRemainingText ?? "—"
        }
        return viewState.balanceText
    }

    private var secondaryValueText: String? {
        guard viewState.isQuota else {
            return nil
        }
        return viewState.quotaUsedText
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

private struct ValueChip: View {
    let label: String?
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            if let label {
                Text(label)
                    .foregroundStyle(UITheme.textTertiary)
            }
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(UITheme.textPrimary)
        }
        .font(.system(size: 9))
        .lineLimit(1)
    }
}

private struct ThinBar: View {
    let ratio: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(UITheme.track)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.65), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width
                            * min(1, max(0, ratio))
                    )
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

private extension AccountHealth {
    var color: Color {
        UITheme.color(for: self)
    }
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

private extension BalanceRowAppearance.Emphasis {
    var color: Color {
        switch self {
        case .primary: UITheme.textPrimary
        case .positive: UITheme.green
        case .warning: UITheme.yellow
        case .muted: UITheme.textTertiary
        case .secondary: UITheme.textSecondary
        case .error: UITheme.red
        case .pending: UITheme.textTertiary
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
                ForEach(segments, id: \.role) { segment in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    segment.role.emphasis.color.opacity(
                                        segment.isActive ? 0.65 : 0.16
                                    ),
                                    segment.role.emphasis.color.opacity(
                                        segment.isActive ? 1 : 0.22
                                    ),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
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

@MainActor
private struct BalanceRowDetailView: View {
    let detail: BalanceRowDetailViewState
    let onRefresh: @MainActor () async -> Void
    @State private var isRefreshing = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(UITheme.textTertiary)
                ForEach(detail.quotaLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(UITheme.textSecondary)
                }
            }
            if let currencyWarningText = detail.currencyWarningText {
                Text(currencyWarningText)
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !detail.breakdown.isEmpty {
                Text(UIStrings.breakdownTitle)
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(UITheme.textTertiary)
                ForEach(detail.breakdown) { item in
                    HStack(spacing: 8) {
                        Text(item.label)
                            .foregroundStyle(UITheme.textSecondary)
                        Spacer(minLength: 8)
                        Text(item.amountText)
                            .monospacedDigit()
                            .foregroundStyle(UITheme.textPrimary)
                    }
                    .font(.system(size: 10))
                }
            }
            if let errorText = detail.errorText {
                Text(UIStrings.errorTitle)
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(UITheme.red)
                Text(errorText)
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.red)
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
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isRefreshing)
            .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.18), in: shape)
        .overlay(shape.strokeBorder(UITheme.hairlineSubtle, lineWidth: 1))
    }

    private func labelledValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(UITheme.textTertiary)
            Spacer(minLength: 8)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(UITheme.textSecondary)
        }
        .font(.system(size: 10))
    }
}

#Preview("模拟数据面板") {
    let monitor = LiveBalanceMonitor(dataSource: .mock(now: Date()))
    BalancePanelView(monitor: monitor)
        .frame(width: 460, height: 420)
        .task { await monitor.refresh() }
}

#Preview("空状态") {
    BalancePanelView(monitor: PreviewBalanceMonitor())
        .frame(width: 460, height: 420)
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
        .frame(width: 460, height: 420)
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
        .frame(width: 460, height: 520)
}

#Preview("Kimi Code 订阅") {
    BalancePanelView(monitor: PreviewBalanceMonitor(rows: makeKimiQuotaRows(now: Date())))
        .frame(width: 460, height: 520)
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
    .frame(width: 460)
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
    .frame(width: 460)
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
        .frame(width: 460, height: 280)
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
        .frame(width: 460, height: 520)
}

#Preview("混合账户类型（Moonshot）") {
    let now = Date()
    let rows = makeMixedKindPreviewRows(now: now)
    BalancePanelView(monitor: PreviewBalanceMonitor(rows: rows))
        .frame(width: 460, height: 640)
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
        onAddAccount: { _ in },
        onRefreshProvider: {},
        onRefreshAccount: { _ in }
    )
    .padding(.vertical, 8)
    .frame(width: 460)
    .background(UITheme.windowBackdrop)
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
