import SwiftUI

/// Shared dark-glass design tokens. The floating panel, Settings, onboarding,
/// dock, and toast all read from this one place so the app keeps a single
/// visual language instead of drifting per screen.
enum UITheme {
    // MARK: - Palette

    static let textPrimary = Color(rgb: 0xECECF1)
    static let textSecondary = Color(rgb: 0xA5A5AF)
    static let textTertiary = Color(rgb: 0x6E6E78)

    static let green = Color(rgb: 0x3ECF8E)
    static let yellow = Color(rgb: 0xE8B339)
    static let red = Color(rgb: 0xE5584E)

    static let topUp = Color(rgb: 0x56B8C6)
    static let subscription = Color(rgb: 0xA88BF0)
    static let points = Color(rgb: 0xE8B339)

    static let hairline = Color.white.opacity(0.09)
    static let hairlineSubtle = Color.white.opacity(0.055)
    static let card = Color.white.opacity(0.045)
    static let cardHover = Color.white.opacity(0.065)
    static let track = Color.white.opacity(0.09)
    static let control = Color.white.opacity(0.06)
    static let controlHover = Color.white.opacity(0.12)

    static let accentStart = Color(rgb: 0x5B8DEF)
    static let accentEnd = Color(rgb: 0x8E6BE8)

    // MARK: - Metrics

    enum Radius {
        static let panel: CGFloat = 26
        static let card: CGFloat = 18
        static let control: CGFloat = 8
        static let chip: CGFloat = 999
    }

    enum Spacing {
        static let panel: CGFloat = 18
        static let card: CGFloat = 12
        static let row: CGFloat = 10
    }

    static let panelWidth: CGFloat = 460
    static let panelHeight: CGFloat = 640

    // MARK: - Fills

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentStart, accentEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var panelTint: LinearGradient {
        LinearGradient(
            colors: [
                Color(rgb: 0x1D1E27).opacity(0.80),
                Color(rgb: 0x101117).opacity(0.88),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var windowBackdrop: some View {
        ZStack {
            Color(rgb: 0x0E0F15)
            RadialGradient(
                colors: [accentStart.opacity(0.20), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 560
            )
            RadialGradient(
                colors: [accentEnd.opacity(0.14), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Health colors

    static func color(for health: AccountHealth) -> Color {
        switch health {
        case .normal: green
        case .warning: yellow
        case .critical: red
        case .unset: textTertiary
        }
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

// MARK: - Glass surfaces

/// The floating panel's rounded glass card. The window is transparent, so the
/// material samples the desktop and the dark tint keeps text legible over any
/// wallpaper.
struct GlassPanelBackground: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: UITheme.Radius.panel, style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.fill(UITheme.panelTint))
            .overlay(shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 32, y: 18)
    }
}

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = 14
    var radius: CGFloat = UITheme.Radius.card

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .background(UITheme.card, in: shape)
            .overlay(shape.strokeBorder(UITheme.hairline, lineWidth: 1))
            .clipShape(shape)
    }
}

extension View {
    func glassCard(
        padding: CGFloat = 14,
        radius: CGFloat = UITheme.Radius.card
    ) -> some View {
        modifier(GlassCardModifier(padding: padding, radius: radius))
    }

    /// Applies the shared dark appearance to a window-level surface.
    func quotrackWindowBackground() -> some View {
        background(UITheme.windowBackdrop)
            .preferredColorScheme(.dark)
    }
}

// MARK: - Buttons

struct GlassIconButton: View {
    let systemName: String
    var help: String?
    var tint: Color = UITheme.textSecondary
    var size: CGFloat = 26
    var isBusy = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isBusy {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(tint)
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: size < 24 ? 10 : 12, weight: .medium))
                        .foregroundStyle(isHovering ? UITheme.textPrimary : tint)
                }
            }
            .frame(width: size, height: size)
            .background(
                isHovering ? UITheme.controlHover : .clear,
                in: RoundedRectangle(cornerRadius: UITheme.Radius.control, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .help(help ?? "")
        .accessibilityLabel(help ?? systemName)
        .onHover { isHovering = $0 }
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                UITheme.accentGradient,
                in: RoundedRectangle(cornerRadius: UITheme.Radius.control, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(UITheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                UITheme.control,
                in: RoundedRectangle(cornerRadius: UITheme.Radius.control, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Small labels

struct TypeTag: View {
    enum Style {
        case topUp
        case subscription
        case mixed
        case experimental
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }

    private var foreground: Color {
        switch style {
        case .topUp: UITheme.topUp
        case .subscription: UITheme.subscription
        case .mixed: UITheme.textSecondary
        case .experimental: UITheme.textTertiary
        }
    }

    private var background: Color {
        switch style {
        case .topUp: UITheme.topUp.opacity(0.10)
        case .subscription: UITheme.subscription.opacity(0.12)
        case .mixed: Color.white.opacity(0.05)
        case .experimental: .clear
        }
    }

    private var border: Color {
        switch style {
        case .topUp: UITheme.topUp.opacity(0.28)
        case .subscription: UITheme.subscription.opacity(0.30)
        case .mixed: UITheme.hairline
        case .experimental: UITheme.hairline
        }
    }
}

struct HealthPill: View {
    let health: AccountHealth
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(UITheme.color(for: health))
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 9.5, weight: .medium))
                .tracking(0.4)
        }
        .foregroundStyle(UITheme.color(for: health))
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(UITheme.color(for: health).opacity(0.10), in: Capsule())
    }
}

// MARK: - Provider mark

struct ProviderMark: View {
    let provider: Provider
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let asset = ProviderBrand.assetName(for: provider) {
                Image(asset)
                    .resizable()
                    .interpolation(.high)
            } else {
                Text(ProviderBrand.monogram(for: provider))
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ProviderBrand.tint(for: provider))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

enum ProviderBrand {
    static func assetName(for provider: Provider) -> String? {
        switch provider {
        case .deepSeek: "DeepSeek"
        case .moonshot: "Moonshot"
        case .openRouter: "OpenRouter"
        case .siliconFlow: nil
        }
    }

    static func monogram(for provider: Provider) -> String {
        switch provider {
        case .deepSeek: "D"
        case .moonshot: "K"
        case .openRouter: "O"
        case .siliconFlow: "S"
        }
    }

    static func tint(for provider: Provider) -> LinearGradient {
        switch provider {
        case .deepSeek:
            LinearGradient(colors: [Color(rgb: 0x2F6BFF), Color(rgb: 0x21C7C9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .moonshot:
            LinearGradient(colors: [Color(rgb: 0x171A24), Color(rgb: 0x3A3F52)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .openRouter:
            LinearGradient(colors: [Color(rgb: 0x5B8DEF), Color(rgb: 0x8E6BE8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .siliconFlow:
            LinearGradient(colors: [Color(rgb: 0x3A3F52), Color(rgb: 0x1B1D27)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Kind helpers

extension AccountKind {
    var typeTagText: String {
        switch self {
        case .balance: "充值"
        case .subscription: "订阅"
        }
    }

    var typeTagStyle: TypeTag.Style {
        switch self {
        case .balance: .topUp
        case .subscription: .subscription
        }
    }
}

extension ProviderGroupViewState {
    /// The Provider-level tag describes the kinds the card actually holds.
    var typeTag: (text: String, style: TypeTag.Style) {
        let kinds = sections.map(\.kind)
        if kinds == [.balance] {
            return ("充值制", .topUp)
        }
        if kinds == [.subscription] {
            return ("订阅制", .subscription)
        }
        return ("充值 + 订阅", .mixed)
    }
}
