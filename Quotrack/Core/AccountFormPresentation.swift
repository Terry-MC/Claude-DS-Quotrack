import Foundation

/// Display rules shared by the onboarding and Settings Account forms. The
/// warning must appear before the user saves, because OpenRouter rejects an
/// ordinary inference key with a permission failure only after a round trip.
enum AccountFormPresentation {
    static func credentialWarning(for provider: Provider) -> String? {
        provider == .openRouter ? UIStrings.openRouterManagementKeyWarning : nil
    }
}
