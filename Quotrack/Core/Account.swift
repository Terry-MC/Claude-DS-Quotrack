import Foundation

/// A single labeled credential for a Provider. A Provider may have several
/// Accounts; each Account is polled and displayed independently. The
/// credential itself lives only in the CredentialStore, never on the Account.
struct Account: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let provider: Provider
    /// Only meaningful for Providers that have Regions; nil otherwise.
    let region: Region?
    let label: String

    init(id: UUID, provider: Provider, region: Region? = nil, label: String) {
        self.id = id
        self.provider = provider
        self.region = region
        self.label = label
    }
}
