import SwiftUI

/// First-run onboarding: Provider, Region when the Provider has one, Account
/// details, then a connection test that must succeed before the Account is
/// saved. The window closes and the panel appears after completion.
@MainActor
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(UITheme.hairline)
                .frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Group {
                        switch model.step {
                        case .provider: providerStep
                        case .region: regionStep
                        case .details: detailsStep
                        case .testing: testingStep
                        case .completed: completedStep
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .scrollIndicators(.never)

            // Keep failures visible: a long details form can scroll the error
            // below the fold, which looks like the test silently did nothing.
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(UITheme.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }

            Rectangle()
                .fill(UITheme.hairline)
                .frame(height: 1)
            footer
        }
        .frame(width: 500, height: 560)
        .quotrackWindowBackground()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Q")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    UITheme.accentGradient,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: UITheme.accentEnd.opacity(0.35), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(UIStrings.onboardingTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UITheme.textPrimary)
                Text(stepTitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(UITheme.textTertiary)
            }

            Spacer(minLength: 8)
            progressDots
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(Array(0..<3), id: \.self) { index in
                Capsule()
                    .fill(
                        index <= stepIndex
                            ? UITheme.accentStart
                            : UITheme.control
                    )
                    .frame(width: index == stepIndex ? 18 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: stepIndex)
        .accessibilityHidden(true)
    }

    private var stepIndex: Int {
        switch model.step {
        case .provider: 0
        case .region: 1
        case .details, .testing, .completed: 2
        }
    }

    private var stepTitle: String {
        switch model.step {
        case .provider: UIStrings.onboardingProviderTitle
        case .region: UIStrings.onboardingRegionTitle
        case .details: UIStrings.onboardingDetailsTitle
        case .testing: UIStrings.onboardingTesting
        case .completed: UIStrings.onboardingSuccess
        }
    }

    private var providerStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(UIStrings.onboardingProviderTitle)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(UITheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(Provider.addableCases, id: \.self) { provider in
                    providerChoice(provider)
                }
            }

            Text(UIStrings.onboardingProviderHint)
                .font(.system(size: 10))
                .foregroundStyle(UITheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Text(UIStrings.unsupportedProvidersExplanation)
                .font(.system(size: 10))
                .foregroundStyle(UITheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let warning = model.credentialWarning {
                Text(warning)
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: model.selectedProvider) { _, newProvider in
            if !newProvider.supportedKinds.contains(model.selectedKind) {
                model.selectedKind = newProvider.supportedKinds.first ?? .balance
                applyThresholdDefaults(for: model.selectedKind)
            }
        }
    }

    private func providerChoice(_ provider: Provider) -> some View {
        let isSelected = model.selectedProvider == provider
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button {
            model.selectedProvider = provider
        } label: {
            HStack(spacing: 10) {
                ProviderMark(provider: provider, size: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.displayName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(UITheme.textPrimary)
                    HStack(spacing: 4) {
                        ForEach(provider.supportedKinds, id: \.self) { kind in
                            TypeTag(
                                text: kind.typeTagText,
                                style: kind.typeTagStyle
                            )
                        }
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        isSelected ? UITheme.accentStart : UITheme.textTertiary
                    )
            }
            .padding(10)
            .background(
                isSelected ? UITheme.accentStart.opacity(0.10) : UITheme.control,
                in: shape
            )
            .overlay(
                shape.strokeBorder(
                    isSelected ? UITheme.accentStart.opacity(0.45) : UITheme.hairline,
                    lineWidth: 1
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var providerSummary: some View {
        HStack(spacing: 8) {
            ProviderMark(provider: model.selectedProvider, size: 22)
            Text(model.selectedProvider.displayName)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(UITheme.textPrimary)
            TypeTag(
                text: model.selectedKind.typeTagText,
                style: model.selectedKind.typeTagStyle
            )
            if model.selectedProvider.supportsRegion {
                Text("· \(model.selectedRegion.displayName)")
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .glassCard(padding: 10)
    }

    private var regionStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            providerSummary
            Text(UIStrings.onboardingRegionTitle)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(UITheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(Region.allCases, id: \.self) { region in
                    regionChoice(region)
                }
            }

            Text(UIStrings.onboardingRegionHint)
                .font(.system(size: 10))
                .foregroundStyle(UITheme.textTertiary)
        }
    }

    private func regionChoice(_ region: Region) -> some View {
        let isSelected = model.selectedRegion == region
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button {
            model.selectedRegion = region
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "globe.asia.australia")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? UITheme.accentStart : UITheme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(
                        UITheme.control,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                Text(region.displayName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(UITheme.textPrimary)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        isSelected ? UITheme.accentStart : UITheme.textTertiary
                    )
            }
            .padding(10)
            .background(
                isSelected ? UITheme.accentStart.opacity(0.10) : UITheme.control,
                in: shape
            )
            .overlay(
                shape.strokeBorder(
                    isSelected ? UITheme.accentStart.opacity(0.45) : UITheme.hairline,
                    lineWidth: 1
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            providerSummary
            VStack(alignment: .leading, spacing: 10) {
                formSectionTitle(UIStrings.onboardingDetailsTitle)
                if model.selectedProvider.supportedKinds.count > 1 {
                    Picker(UIStrings.accountKindLabel, selection: $model.selectedKind) {
                        ForEach(model.selectedProvider.supportedKinds, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: model.selectedKind) { _, newKind in
                        applyThresholdDefaults(for: newKind)
                    }
                } else {
                    HStack {
                        Text(UIStrings.accountKindLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(UITheme.textTertiary)
                        Spacer()
                        Text(model.selectedKind.displayName)
                            .font(.system(size: 11.5))
                            .foregroundStyle(UITheme.textPrimary)
                    }
                }

                OnboardingField(
                    title: UIStrings.onboardingLabelField,
                    text: $model.label
                )
                OnboardingField(
                    title: UIStrings.onboardingCredentialField,
                    text: $model.credential,
                    isSecure: true
                )
                if let warning = model.credentialWarning {
                    Text(warning)
                        .font(.system(size: 10))
                        .foregroundStyle(UITheme.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.selectedKind == .subscription,
                   !model.credential.isEmpty,
                   !model.credential.hasPrefix("sk-kimi") {
                    Text(UIStrings.kimiCodeCredentialRequired)
                        .font(.system(size: 10))
                        .foregroundStyle(UITheme.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .glassCard(padding: 14)

            VStack(alignment: .leading, spacing: 10) {
                formSectionTitle(UIStrings.healthThresholdsTitle)
                HStack(spacing: 10) {
                    OnboardingField(
                        title: warningFieldLabel,
                        text: $model.warningThresholdText
                    )
                    OnboardingField(
                        title: criticalFieldLabel,
                        text: $model.criticalThresholdText
                    )
                }
                Text(thresholdHint)
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(UIStrings.onboardingCredentialHint)
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .glassCard(padding: 14)
        }
    }

    private func applyThresholdDefaults(for kind: AccountKind) {
        let defaults = AccountThresholds.defaults(for: kind)
        model.warningThresholdText = defaults.warning?.description ?? ""
        model.criticalThresholdText = defaults.critical?.description ?? ""
    }

    private var warningFieldLabel: String {
        model.selectedKind == .subscription
            ? UIStrings.warningThresholdPercentLabel
            : UIStrings.warningThresholdLabel
    }

    private var criticalFieldLabel: String {
        model.selectedKind == .subscription
            ? UIStrings.criticalThresholdPercentLabel
            : UIStrings.criticalThresholdLabel
    }

    private var thresholdHint: String {
        model.selectedKind == .subscription
            ? UIStrings.healthThresholdsPercentHint
            : UIStrings.healthThresholdsHint
    }

    private var testingStep: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(UITheme.accentStart)
            Text(UIStrings.onboardingTesting)
                .font(.system(size: 12))
                .foregroundStyle(UITheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }

    private var completedStep: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(UITheme.green)
            Text(UIStrings.onboardingSuccess)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(UITheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if showsBackButton {
                Button(UIStrings.onboardingBack) {
                    model.back()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Spacer()
            switch model.step {
            case .provider, .region:
                Button(UIStrings.onboardingNext) {
                    model.advance()
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
            case .details:
                Button(UIStrings.onboardingTestAndSave) {
                    Task {
                        await model.submit()
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(
                    model.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || model.credential.isEmpty
                )
            case .testing:
                EmptyView()
            case .completed:
                Button(UIStrings.onboardingDone) {
                    onFinish()
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var showsBackButton: Bool {
        switch model.step {
        case .region, .details: true
        case .provider, .testing, .completed: false
        }
    }
}

private struct OnboardingField: View {
    let title: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(UITheme.textTertiary)
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 11.5))
            .foregroundStyle(UITheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                UITheme.control,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(UITheme.hairline, lineWidth: 1)
            )
        }
    }
}

private func formSectionTitle(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(0.5)
        .foregroundStyle(UITheme.textSecondary)
}
