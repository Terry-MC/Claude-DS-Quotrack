import SwiftUI

/// The dock's visual content. It renders a pure `DockPresentation`, so every
/// state can be previewed without a monitor, a window, or polling.
@MainActor
struct DockContentView: View {
    let presentation: DockPresentation
    var onOpen: () -> Void = {}

    @State private var pulseExpanded = false

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 10) {
                mark
                statusDot
                if let badgeText = presentation.badgeText {
                    badge(text: badgeText)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
            .contentShape(dockShape)
        }
        .buttonStyle(.plain)
        .help(UIStrings.dockOpenPanelHint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityDescription)
        .accessibilityHint(UIStrings.dockOpenPanelHint)
        .accessibilityAddTraits(.isButton)
        .onAppear(perform: updatePulse)
        .onChange(of: presentation.isPulsing) {
            updatePulse()
        }
    }

    private var dockShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    private var mark: some View {
        Image(systemName: "chart.bar.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(presentation.status == .normal ? Color.secondary : tint)
            .frame(width: 34, height: 34)
            .background(
                tint.opacity(presentation.status == .normal ? 0.10 : 0.16),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    /// A ring expands away from the dot only in the critical state. Reduce
    /// Motion turns the ring off entirely; the dot stays solid and visible.
    private var statusDot: some View {
        ZStack {
            if presentation.isPulsing {
                Circle()
                    .stroke(tint.opacity(0.55), lineWidth: 2)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulseExpanded ? 2.0 : 1.0)
                    .opacity(pulseExpanded ? 0 : 0.85)
            }
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 20)
            .padding(.vertical, 2)
            .background(tint, in: Capsule())
            .accessibilityHidden(true)
    }

    private var background: some View {
        dockShape
            .fill(.regularMaterial)
            .overlay(dockShape.fill(tint.opacity(tintOpacity)))
            .overlay(
                dockShape.strokeBorder(
                    tint.opacity(borderOpacity),
                    lineWidth: 1
                )
            )
    }

    private var tint: Color {
        switch presentation.status {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    private var tintOpacity: Double {
        switch presentation.status {
        case .normal: 0.04
        case .warning: 0.12
        case .critical: 0.15
        }
    }

    private var borderOpacity: Double {
        switch presentation.status {
        case .normal: 0.18
        case .warning: 0.45
        case .critical: 0.55
        }
    }

    private func updatePulse() {
        guard presentation.isPulsing else {
            pulseExpanded = false
            return
        }
        pulseExpanded = false
        withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
            pulseExpanded = true
        }
    }
}

@MainActor
private func previewDock(_ presentation: DockPresentation) -> some View {
    DockContentView(presentation: presentation)
        .frame(
            width: DockFrameCalculator.defaultSize.width,
            height: DockFrameCalculator.defaultSize.height
        )
        .padding(48)
        .background(
            LinearGradient(
                colors: [.gray.opacity(0.28), .gray.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
}

#Preview("Dock 正常") {
    previewDock(DockPresentation.make(healths: [.normal], reduceMotion: false))
}

#Preview("Dock 零计数") {
    previewDock(DockPresentation.make(healths: [], reduceMotion: false))
}

#Preview("Dock 预警") {
    previewDock(
        DockPresentation.make(
            healths: [.normal, .warning, .warning],
            reduceMotion: false
        )
    )
}

#Preview("Dock 紧急") {
    previewDock(
        DockPresentation.make(
            healths: [.warning, .critical, .critical],
            reduceMotion: false
        )
    )
}

#Preview("Dock 紧急 · 减弱动态效果") {
    previewDock(
        DockPresentation.make(
            healths: [.critical],
            reduceMotion: true
        )
    )
}
