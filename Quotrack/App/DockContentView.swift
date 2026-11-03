import SwiftUI

/// The dock's visual content. It renders a pure `DockPresentation`, so every
/// state can be previewed without a monitor, a window, or polling.
///
/// The dock is deliberately quiet: a slim glass tab with one status-colored
/// edge bar, a dot, and a count. The tint never floods the whole surface.
@MainActor
struct DockContentView: View {
    let presentation: DockPresentation

    @State private var pulseExpanded = false

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(tint.opacity(accentOpacity))
                .frame(width: 2)
                .padding(.vertical, 12)
                .padding(.leading, 4)

            VStack(spacing: 8) {
                Text("Q")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(UITheme.textSecondary)

                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .shadow(color: tint.opacity(dotGlow), radius: 4)

                ZStack {
                    if let badgeText = presentation.badgeText {
                        Text(badgeText)
                            .font(
                                .system(size: 9, weight: .medium)
                                    .monospacedDigit()
                            )
                            .foregroundStyle(badgeColor)
                    }
                }
                .frame(height: 10)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .accessibilityHidden(true)
        .onAppear(perform: updatePulse)
        .onChange(of: presentation.isPulsing) {
            updatePulse()
        }
        .preferredColorScheme(.dark)
    }

    private var dockShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 14,
            bottomLeadingRadius: 14,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    private var background: some View {
        dockShape
            .fill(.ultraThinMaterial)
            .overlay(dockShape.fill(UITheme.panelTint))
            .overlay(dockShape.fill(tint.opacity(tintOpacity)))
            .overlay(
                dockShape.strokeBorder(
                    borderColor,
                    lineWidth: 1
                )
            )
    }

    private var tint: Color {
        switch presentation.status {
        case .normal: UITheme.green
        case .warning: UITheme.yellow
        case .critical: UITheme.red
        }
    }

    private var badgeColor: Color {
        switch presentation.status {
        case .normal: UITheme.textTertiary
        case .warning: UITheme.yellow
        case .critical: UITheme.red
        }
    }

    private var tintOpacity: Double {
        switch presentation.status {
        case .normal: 0
        case .warning: 0.03
        case .critical: 0.05
        }
    }

    private var borderColor: Color {
        switch presentation.status {
        case .normal: Color.white.opacity(0.10)
        case .warning: UITheme.yellow.opacity(0.28)
        case .critical: UITheme.red.opacity(0.32)
        }
    }

    private var accentOpacity: Double {
        guard presentation.isPulsing else {
            return presentation.status == .normal ? 0.55 : 0.8
        }
        return pulseExpanded ? 0.30 : 0.95
    }

    private var dotGlow: Double {
        presentation.isPulsing && pulseExpanded ? 0.35 : 0.65
    }

    private func updatePulse() {
        guard presentation.isPulsing else {
            pulseExpanded = false
            return
        }
        pulseExpanded = false
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
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
                colors: [.black, Color(rgb: 0x1B1D27)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
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
