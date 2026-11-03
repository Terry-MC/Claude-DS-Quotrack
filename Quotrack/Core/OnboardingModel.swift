import Foundation
import Observation

/// Drives first-run onboarding: Provider, Region when the Provider has one,
/// Account details, then a test connection that must succeed before the
/// Account is saved. The final step signals that the panel can be shown.
@MainActor
@Observable
final class OnboardingModel {
    enum Step: Equatable, Sendable {
        case provider
        case region
        case details
        case testing
        case completed
    }

    private(set) var step: Step = .provider
    var selectedProvider: Provider = .deepSeek
    var selectedRegion: Region = .domestic
    var selectedKind: AccountKind = .balance
    var label = ""
    var credential = ""
    var warningThresholdText = ""
    var criticalThresholdText = ""
    private(set) var errorMessage: String?
    private(set) var completedAccount: Account?

    /// Warning shown before the credential is entered or saved. Currently only
    /// OpenRouter needs a management key instead of an inference key.
    var credentialWarning: String? {
        AccountFormPresentation.credentialWarning(
            for: selectedProvider,
            kind: selectedKind
        )
    }

    @ObservationIgnored private let accountManager: AccountManager
    @ObservationIgnored private let connectionTester: any ConnectionTesting

    init(
        accountManager: AccountManager,
        connectionTester: any ConnectionTesting,
        initialProvider: Provider? = nil
    ) {
        self.accountManager = accountManager
        self.connectionTester = connectionTester
        guard let initialProvider, initialProvider.isSupported else {
            return
        }
        selectedProvider = initialProvider
        selectedKind = initialProvider.supportedKinds.first ?? .balance
        let defaults = AccountThresholds.defaults(for: selectedKind)
        warningThresholdText = defaults.warning?.description ?? ""
        criticalThresholdText = defaults.critical?.description ?? ""
        // A Provider-card plus button means "add for this Provider"; skip the
        // picker but keep it reachable through Back.
        step = initialProvider.supportsRegion ? .region : .details
    }

    /// Moves forward from Provider selection or Region selection. Details are
    /// submitted separately because they require a connection test.
    func advance() {
        switch step {
        case .provider:
            step = selectedProvider.supportsRegion ? .region : .details
        case .region:
            step = .details
        case .details, .testing, .completed:
            break
        }
    }

    func back() {
        switch step {
        case .provider, .testing, .completed:
            break
        case .region:
            step = .provider
        case .details:
            step = selectedProvider.supportsRegion ? .region : .provider
        }
    }

    /// Tests the entered credential first; only a successful test saves the
    /// Account. A failure returns to the details step with a message, leaving
    /// no Account metadata or Keychain item behind.
    func submit() async {
        guard step == .details else {
            return
        }
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            errorMessage = AccountManagerError.missingLabel.localizedDescription
            return
        }
        guard !credential.isEmpty else {
            errorMessage = AccountManagerError.missingCredential.localizedDescription
            return
        }
        let provider = selectedProvider
        let kind = provider.supportedKinds.contains(selectedKind)
            ? selectedKind
            : (provider.supportedKinds.first ?? .balance)
        guard let thresholds = validatedThresholds(for: kind) else {
            return
        }

        errorMessage = nil
        step = .testing
        let draft = AccountDraft(
            provider: provider,
            region: provider.supportsRegion ? selectedRegion : nil,
            label: trimmedLabel,
            credential: credential,
            kind: kind
        )
        do {
            let creator = AccountCreator(
                manager: accountManager,
                connectionTester: connectionTester
            )
            let account = try await creator.create(
                draft,
                thresholds: thresholds
            )
            completedAccount = account
            step = .completed
        } catch {
            errorMessage = ConnectionErrorMessage.text(
                for: error,
                provider: provider,
                kind: kind
            )
            step = .details
        }
    }

    private func validatedThresholds(for kind: AccountKind) -> AccountThresholds? {
        switch ThresholdInput.parseThresholds(
            warningText: warningThresholdText,
            criticalText: criticalThresholdText,
            kind: kind
        ) {
        case let .success(thresholds):
            return thresholds
        case .failure:
            errorMessage = UIStrings.invalidThreshold
            return nil
        }
    }
}
