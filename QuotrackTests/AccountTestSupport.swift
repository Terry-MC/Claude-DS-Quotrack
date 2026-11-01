import Foundation

extension AccountManager {
    /// Keeps older Account tests readable while the production API carries an
    /// `AccountDraft` instead of four repeated parameters.
    @discardableResult
    func addAccount(
        provider: Provider,
        region: Region? = nil,
        label: String,
        credential: String
    ) throws -> Account {
        try addAccount(
            AccountDraft(
                provider: provider,
                region: region,
                label: label,
                credential: credential
            )
        )
    }
}
