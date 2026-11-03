import Foundation

/// The metric family an Account belongs to. A Balance Account reports money; a
/// Quota Account reports a usage allowance. The kind is fixed at creation
/// because the credential and endpoint depend on it.
enum AccountKind: String, Codable, Sendable, Equatable, CaseIterable {
    case balance
    case subscription

    var displayName: String {
        switch self {
        case .balance: "充值"
        case .subscription: "订阅"
        }
    }
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

enum AccountThresholdError: Error, Equatable, Sendable {
    case valueOutOfRange
    case criticalNotBelowWarning
}

extension AccountThresholds {
    /// A new Quota Account starts with a 10% remaining warning line; the user
    /// can edit or clear it. Balance Accounts have no default because the
    /// meaningful amount depends on the Account's currency and usage.
    static func defaults(for kind: AccountKind) -> AccountThresholds {
        switch kind {
        case .balance:
            AccountThresholds()
        case .subscription:
            AccountThresholds(warning: 10)
        }
    }

    /// Balance thresholds are positive currency amounts. Quota thresholds are
    /// remaining percentages in 0...100. Both kinds require critical to be
    /// below warning when both are set.
    func validate(for kind: AccountKind) throws {
        switch kind {
        case .balance:
            for value in [warning, critical].compactMap({ $0 }) where value <= 0 {
                throw AccountThresholdError.valueOutOfRange
            }
        case .subscription:
            for value in [warning, critical].compactMap({ $0 })
            where value < 0 || value > 100 {
                throw AccountThresholdError.valueOutOfRange
            }
        }
        if let warning, let critical, critical >= warning {
            throw AccountThresholdError.criticalNotBelowWarning
        }
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
    /// The currency a Balance Account's thresholds are expressed in. `nil`
    /// means the Account predates currency binding; the evaluator then accepts
    /// the Snapshot's currency. Quota Accounts do not use this field.
    let currency: Currency?
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
        currency: Currency? = nil,
        label: String,
        warningThreshold: Decimal? = nil,
        criticalThreshold: Decimal? = nil
    ) {
        self.id = id
        self.provider = provider
        self.region = region
        self.kind = kind
        self.currency = currency
        self.label = label
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
    }

    /// Returns a copy with a new label while preserving identity, Provider,
    /// Region, kind, and both thresholds.
    func with(label: String) -> Account {
        Account(
            id: id,
            provider: provider,
            region: region,
            kind: kind,
            currency: currency,
            label: label,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
    }

    /// Returns a copy with both thresholds replaced while preserving identity,
    /// Provider, Region, kind, currency, and label.
    func with(thresholds: AccountThresholds) -> Account {
        Account(
            id: id,
            provider: provider,
            region: region,
            kind: kind,
            currency: currency,
            label: label,
            warningThreshold: thresholds.warning,
            criticalThreshold: thresholds.critical
        )
    }

}

extension Account {
    private enum CodingKeys: String, CodingKey {
        case id
        case provider
        case region
        case kind
        case currency
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
        let kind = try container.decodeIfPresent(AccountKind.self, forKey: .kind) ?? .balance
        self.kind = kind
        self.currency = try container.decodeIfPresent(Currency.self, forKey: .currency)
        self.label = try container.decode(String.self, forKey: .label)
        let warning = try container.decodeIfPresent(Decimal.self, forKey: .warningThreshold)
        let legacy = try container.decodeIfPresent(Decimal.self, forKey: .lowBalanceThreshold)
        let critical = try container.decodeIfPresent(Decimal.self, forKey: .criticalThreshold)
        let decoded = AccountThresholds(warning: warning ?? legacy, critical: critical)
        do {
            try decoded.validate(for: kind)
            self.warningThreshold = decoded.warning
            self.criticalThreshold = decoded.critical
        } catch {
            // Hand-edited or older files can contain an invalid pair. Treat it
            // as unset rather than carrying a Health rule the UI cannot honor.
            self.warningThreshold = nil
            self.criticalThreshold = nil
        }
    }

    /// Writes the v2 shape. The legacy `lowBalanceThreshold` key is accepted on
    /// decode but never written.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(provider, forKey: .provider)
        try container.encodeIfPresent(region, forKey: .region)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(currency, forKey: .currency)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(warningThreshold, forKey: .warningThreshold)
        try container.encodeIfPresent(criticalThreshold, forKey: .criticalThreshold)
    }
}
