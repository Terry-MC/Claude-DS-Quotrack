import AppKit
import SwiftUI

/// The in-app fallback when notification permission is denied. A small,
/// non-activating floating panel in the top-right corner shows the same
/// aggregated content, dismisses itself, and opens the panel on click.
@MainActor
final class HealthToastWindowController: HealthToastPresenting {
    private static let contentSize = NSSize(width: 330, height: 116)
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

    private static let width: CGFloat = 330

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbolName)
                        .font(.title3)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(content.title)
                            .font(.headline)
                        Text(content.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(UIStrings.dismissNotificationToast)
        }
        .padding(12)
        .frame(width: Self.width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.secondary.opacity(0.25))
        )
    }

    private var symbolName: String {
        switch content.severity {
        case .critical:
            "exclamationmark.octagon.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .normal, .unset:
            "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch content.severity {
        case .critical:
            .red
        case .warning:
            .orange
        case .normal, .unset:
            .green
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
