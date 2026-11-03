import AppKit
import SwiftUI

/// The in-app fallback when notification permission is denied. A small,
/// non-activating floating panel in the top-right corner shows the same
/// aggregated content, dismisses itself, and opens the panel on click.
@MainActor
final class HealthToastWindowController: HealthToastPresenting {
    private static let contentSize = NSSize(width: 340, height: 132)
    private static let visibleDuration: Duration = .seconds(8)

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(
        _ content: HealthNotificationContent,
        onOpen: @escaping @MainActor () -> Void
    ) {
        dismiss()
        let panel = makePanel()
        panel.contentView = NSHostingView(
            rootView: HealthToastView(
                content: content,
                onOpen: { [weak self] in
                    self?.dismiss()
                    onOpen()
                },
                onDismiss: { [weak self] in self?.dismiss() }
            )
        )
        position(panel)
        self.panel = panel
        panel.orderFrontRegardless()

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleDuration)
            guard !Task.isCancelled else {
                return
            }
            self?.dismiss()
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setContentSize(Self.contentSize)
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else {
            panel.center()
            return
        }
        panel.setFrameOrigin(
            NSPoint(
                x: visibleFrame.maxX - panel.frame.width - 16,
                y: visibleFrame.maxY - panel.frame.height - 16
            )
        )
    }

    private func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

@MainActor
private struct HealthToastView: View {
    let content: HealthNotificationContent
    let onOpen: () -> Void
    let onDismiss: () -> Void

    private static let width: CGFloat = 340

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(alignment: .top, spacing: 9) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 11) {
                    Text("Q")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            UITheme.accentGradient,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .shadow(color: UITheme.accentEnd.opacity(0.30), radius: 8, y: 3)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("QUOTRACK")
                                .tracking(0.5)
                            Spacer(minLength: 8)
                            Text("现在")
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(UITheme.textTertiary)

                        Text(content.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(UITheme.textPrimary)
                        Text(content.body)
                            .font(.system(size: 10.5))
                            .foregroundStyle(UITheme.textSecondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(UIStrings.notificationOpenHint)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(UITheme.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(
                        UITheme.control,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(UIStrings.dismissNotificationToast)
        }
        .padding(13)
        .frame(width: Self.width, alignment: .leading)
        .background(
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(UITheme.panelTint))
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint.opacity(0.8))
                .frame(width: 2)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )
        }
        .overlay(
            shape.strokeBorder(UITheme.hairline, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private var tint: Color {
        switch content.severity {
        case .critical:
            UITheme.red
        case .warning:
            UITheme.yellow
        case .normal, .unset:
            UITheme.green
        }
    }
}

#Preview("健康提醒 Toast") {
    HealthToastView(
        content: HealthNotificationContent(
            title: UIStrings.healthNotificationTitle,
            body: "DeepSeek · 个人账户：正常 → 预警",
            severity: .warning,
            affectedAccountIDs: [UUID()]
        ),
        onOpen: {},
        onDismiss: {}
    )
    .padding()
}
