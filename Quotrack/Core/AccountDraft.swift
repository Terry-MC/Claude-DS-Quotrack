import Foundation

/// The user-entered identity and credential for an Account that does not exist
/// yet. Connection testing, onboarding, and Account creation all carry these
/// fields together instead of repeating the same four parameters.
struct AccountDraft: Equatable, Sendable {
    let provider: Provider
    let region: Region?
    let label: String
    let credential: String

    init(
        provider: Provider,
        region: Region? = nil,
        label: String,
        credential: String
    ) {
        self.provider = provider
        self.region = region
        self.label = label
        self.credential = credential
    }

    /// The Region an Account should persist. Region-capable Providers default
    /// to domestic; Providers without Regions never store one.
    var normalizedRegion: Region? {
        provider.supportsRegion ? (region ?? .domestic) : nil
    }
}
