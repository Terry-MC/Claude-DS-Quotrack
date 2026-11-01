import Foundation
import SwiftUI

/// The floating panel's content. It observes the concrete BalanceMonitor so
/// row updates from polling re-render the panel, and renders the view state
/// derived in the shared core.
@MainActor
struct BalancePanelView: View {
    let monitor: LiveBalanceMonitor
    @State private var expansion = BalanceRowExpansion()

    var body: some View {
        let rows = monitor.rows
        let header = PanelHeaderPresentation.viewState(for: rows)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(header.healthyText)
                    .foregroundStyle(.green)
                Text(header.errorText)
                    .foregroundStyle(.red)
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        BalanceRowView(
                            viewState: BalanceRowPresentation.viewState(for: row, now: Date()),
                            detail: BalanceRowPresentation.detailViewState(for: row),
                            isExpanded: expansion.isExpanded(row.id),
                            onToggle: { expansion.toggle(row.id) },
                            onRefresh: { await monitor.refresh(accountID: row.id) }
                        )
                        Divider()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor
private struct BalanceRowView: View {
    let viewState: BalanceRowViewState
    let detail: BalanceRowDetailViewState
    let isExpanded: Bool
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
                        Text(viewState.providerName)
                            .font(.headline)
                        Text(viewState.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(viewState.balanceText)
                            .font(.title3)
                            .monospacedDigit()
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

    private var statusColor: Color {
        switch viewState.status {
        case .some(.fresh): .green
        case .some(.stale): .gray
        case .some(.unavailable): .orange
        case .some(.error): .red
        case .none: .secondary
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
    let row = BalanceRow(account: account, snapshot: snapshot, status: .fresh)
    BalanceRowView(
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
        viewState: BalanceRowPresentation.viewState(for: row, now: Date()),
        detail: BalanceRowPresentation.detailViewState(for: row),
        isExpanded: true,
        onToggle: {},
        onRefresh: {}
    )
    .padding()
    .frame(width: 360)
}
