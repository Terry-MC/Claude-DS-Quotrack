import Foundation

/// Display rules shared by the onboarding and Settings Account forms. The
/// warning must appear before the user saves, because OpenRouter rejects an
/// ordinary inference key with a permission failure only after a round trip.
enum AccountFormPresentation {
    static func credentialWarning(
        for provider: Provider,
        kind: AccountKind = .balance
    ) -> String? {
        if provider == .openRouter {
            return UIStrings.openRouterManagementKeyWarning
        }
        if provider == .moonshot && kind == .subscription {
            return UIStrings.kimiCodeCredentialWarning
        }
        return nil
    }
}
