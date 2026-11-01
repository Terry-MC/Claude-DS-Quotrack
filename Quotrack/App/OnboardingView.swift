import SwiftUI

/// First-run onboarding: Provider, Region when the Provider has one, Account
/// details, then a connection test that must succeed before the Account is
/// saved. The window closes and the panel appears after completion.
@MainActor
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(UIStrings.onboardingTitle)
                    .font(.title2.weight(.semibold))
                Text(stepTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

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

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(24)
        .frame(width: 460, height: 420)
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
            Picker(UIStrings.onboardingProviderTitle, selection: $model.selectedProvider) {
                ForEach(Provider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text(UIStrings.onboardingProviderHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(UIStrings.unsupportedProvidersExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var regionStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(UIStrings.onboardingRegionTitle, selection: $model.selectedRegion) {
                ForEach(Region.allCases, id: \.self) { region in
                    Text(region.displayName).tag(region)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text(UIStrings.onboardingRegionHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(UIStrings.onboardingLabelField, text: $model.label)
                .textFieldStyle(.roundedBorder)
            SecureField(UIStrings.onboardingCredentialField, text: $model.credential)
                .textFieldStyle(.roundedBorder)
            Text(UIStrings.onboardingCredentialHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var testingStep: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(UIStrings.onboardingTesting)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var completedStep: some View {
        Label(UIStrings.onboardingSuccess, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if showsBackButton {
                Button(UIStrings.onboardingBack) {
                    model.back()
                }
            }
            Spacer()
            switch model.step {
            case .provider, .region:
                Button(UIStrings.onboardingNext) {
                    model.advance()
                }
                .keyboardShortcut(.defaultAction)
            case .details:
                Button(UIStrings.onboardingTestAndSave) {
                    Task {
                        await model.submit()
                    }
                }
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
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var showsBackButton: Bool {
        switch model.step {
        case .region, .details: true
        case .provider, .testing, .completed: false
        }
    }
}
