import Foundation

/// The metric family an Account belongs to. A Balance Account reports money; a
/// Quota Account reports a usage allowance. The kind is fixed at creation
/// because the credential and endpoint depend on it.
enum AccountKind: String, Codable, Sendable, Equatable, CaseIterable {
    case balance
    case subscription
}

/// The two optional levels an Account can use to derive its Health. For a
/// Balance Account these are currency amounts; for a Quota Account they are
/// remaining percentages. Validation lives with the AccountManager mutation.
struct AccountThresholds: Equatable, Sendable {
    let warning: Decimal?
    let critical: Decimal?

    init(warning: Decimal? = nil, critical: Decimal? = nil) {
        self.warning = warning
        self.critical = critical
    }
}

/// A single labeled credential for a Provider. A Provider may have several
/// Accounts; each Account is polled and displayed independently. The
/// credential itself lives only in the CredentialStore, never on the Account.
struct Account: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let provider: Provider
    /// Only meaningful for Providers that have Regions; nil otherwise.
    let region: Region?
    let kind: AccountKind
    let label: String
    /// The Balance below which the Account warns. `nil` means the warning is
    /// off. Kept separate from `criticalThreshold` so the two levels can be
    /// configured independently.
    let warningThreshold: Decimal?
    /// The Balance below which the Account is critical. `nil` means no
    /// critical level.
    let criticalThreshold: Decimal?

    init(
        id: UUID,
        provider: Provider,
        region: Region? = nil,
        kind: AccountKind = .balance,
        label: String,
        warningThreshold: Decimal? = nil,
        criticalThreshold: Decimal? = nil
    ) {
        self.id = id
        self.provider = provider
        self.region = region
        self.kind = kind
        self.label = label
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
    }

    /// v1 compatibility: the single low-Balance threshold maps to the warning
    /// threshold. The v1 UI still calls this path until the Balance health
    /// ticket migrates it.
    init(
        id: UUID,
        provider: Provider,
        region: Region? = nil,
        label: String,
        lowBalanceThreshold: Decimal?
    ) {
        self.init(
            id: id,
            provider: provider,
            region: region,
            kind: .balance,
            label: label,
            warningThreshold: lowBalanceThreshold,
            criticalThreshold: nil
        )
    }

    /// v1 compatibility alias. New code uses `warningThreshold`.
    var lowBalanceThreshold: Decimal? {
        warningThreshold
    }

    /// Returns a copy with a new label while preserving identity, Provider,
    /// Region, kind, and both thresholds.
    func with(label: String) -> Account {
        Account(
            id: id,
            provider: provider,
            region: region,
            kind: kind,
            label: label,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
    }

    /// Returns a copy with both thresholds replaced while preserving identity,
    /// Provider, Region, kind, and label.
    func with(thresholds: AccountThresholds) -> Account {
        Account(
            id: id,
            provider: provider,
            region: region,
            kind: kind,
            label: label,
            warningThreshold: thresholds.warning,
            criticalThreshold: thresholds.critical
        )
    }

    /// Returns a copy with the v1 single threshold applied as the warning
    /// threshold. The critical threshold is cleared because the v1 path has no
    /// second level.
    func with(lowBalanceThreshold: Decimal?) -> Account {
        Account(
            id: id,
            provider: provider,
            region: region,
            kind: kind,
            label: label,
            warningThreshold: lowBalanceThreshold,
            criticalThreshold: nil
        )
    }
}

extension Account {
    private enum CodingKeys: String, CodingKey {
        case id
        case provider
        case region
        case kind
        case label
        case warningThreshold
        case criticalThreshold
        case lowBalanceThreshold
    }

    /// Decodes v1 metadata that has no kind and a single low-Balance threshold,
    /// as well as v2 metadata with kind and both thresholds.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.provider = try container.decode(Provider.self, forKey: .provider)
        self.region = try container.decodeIfPresent(Region.self, forKey: .region)
        self.kind = try container.decodeIfPresent(AccountKind.self, forKey: .kind) ?? .balance
        self.label = try container.decode(String.self, forKey: .label)
        let warning = try container.decodeIfPresent(Decimal.self, forKey: .warningThreshold)
        let legacy = try container.decodeIfPresent(Decimal.self, forKey: .lowBalanceThreshold)
        self.warningThreshold = warning ?? legacy
        self.criticalThreshold = try container.decodeIfPresent(Decimal.self, forKey: .criticalThreshold)
    }

    /// Writes the v2 shape. The legacy `lowBalanceThreshold` key is accepted on
    /// decode but never written.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(provider, forKey: .provider)
        try container.encodeIfPresent(region, forKey: .region)
        try container.encode(kind, forKey: .kind)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(warningThreshold, forKey: .warningThreshold)
        try container.encodeIfPresent(criticalThreshold, forKey: .criticalThreshold)
    }
}
