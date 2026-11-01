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
    var label = ""
    var credential = ""
    private(set) var errorMessage: String?
    private(set) var completedAccount: Account?

    @ObservationIgnored private let accountManager: AccountManager
    @ObservationIgnored private let connectionTester: any ConnectionTesting

    init(
        accountManager: AccountManager,
        connectionTester: any ConnectionTesting
    ) {
        self.accountManager = accountManager
        self.connectionTester = connectionTester
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

        errorMessage = nil
        step = .testing
        let provider = selectedProvider
        let region = provider.supportsRegion ? selectedRegion : nil
        do {
            _ = try await connectionTester.testConnection(
                provider: provider,
                region: region,
                credential: credential
            )
            let account = try accountManager.addAccount(
                provider: provider,
                region: region,
                label: trimmedLabel,
                credential: credential
            )
            completedAccount = account
            step = .completed
        } catch {
            errorMessage = Self.userMessage(for: error, provider: provider)
            step = .details
        }
    }

    private static func userMessage(for error: any Error, provider: Provider) -> String {
        if let balanceError = error as? BalanceProviderError {
            return balanceError.userMessage(for: provider)
        }
        return error.localizedDescription
    }
}
