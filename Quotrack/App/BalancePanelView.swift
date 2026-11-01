import SwiftUI

/// The floating panel's content. It depends only on the BalanceMonitor seam
/// and renders the view state derived in the shared core.
@MainActor
struct BalancePanelView: View {
    let monitor: any BalanceMonitor

    var body: some View {
        let header = PanelHeaderPresentation.viewState(for: monitor.rows)
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
                    ForEach(monitor.rows) { row in
                        BalanceRowView(
                            viewState: BalanceRowPresentation.viewState(for: row, now: Date())
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

    var body: some View {
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
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
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
