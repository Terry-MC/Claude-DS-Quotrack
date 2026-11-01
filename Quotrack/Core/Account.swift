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
    /// The Balance below which the row warns visually. `nil` means the
    /// low-Balance warning is off, which is the default for a new Account.
    let lowBalanceThreshold: Decimal?

    init(
        id: UUID,
        provider: Provider,
        region: Region? = nil,
        label: String,
        lowBalanceThreshold: Decimal? = nil
    ) {
        self.id = id
        self.provider = provider
        self.region = region
        self.label = label
        self.lowBalanceThreshold = lowBalanceThreshold
    }

    /// Returns a copy with a new label while preserving identity, Provider,
    /// Region, and threshold.
    func with(label: String) -> Account {
        Account(
            id: id,
            provider: provider,
            region: region,
            label: label,
            lowBalanceThreshold: lowBalanceThreshold
        )
    }

    /// Returns a copy with the low-Balance warning enabled or cleared while
    /// preserving identity, Provider, Region, and label.
    func with(lowBalanceThreshold: Decimal?) -> Account {
        Account(
            id: id,
            provider: provider,
            region: region,
            label: label,
            lowBalanceThreshold: lowBalanceThreshold
        )
    }
}
