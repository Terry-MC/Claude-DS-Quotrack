import Foundation

/// Turns a saved Provider failure into the message shown to the user. Both
/// onboarding and the Settings add flow test a draft before saving, so they
/// share the same Provider-aware explanation.
enum ConnectionErrorMessage {
    static func text(
        for error: any Error,
        provider: Provider,
        kind: AccountKind? = nil
    ) -> String {
        if let balanceError = error as? BalanceProviderError {
            if balanceError.category == .authentication,
               provider == .moonshot,
               kind == .subscription {
                return UIStrings.kimiCodeAuthenticationError
            }
            return balanceError.userMessage(for: provider)
        }
        return error.localizedDescription
    }
}
