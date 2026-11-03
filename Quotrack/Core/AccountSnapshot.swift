import Foundation

/// One named component of a Quota, such as a subscription allowance or a
/// bonus points package.
struct QuotaPackage: Codable, Equatable, Sendable, Identifiable {
    let name: String
    let limit: Decimal
    let remaining: Decimal
    let expiresAt: Date?

    init(
        name: String,
        limit: Decimal,
        remaining: Decimal,
        expiresAt: Date? = nil
    ) {
        self.name = name
        self.limit = limit
        self.remaining = remaining
        self.expiresAt = expiresAt
    }

    var id: String { name }
}

/// The result of one quota query for one Account at one point in time: the
/// allowance, what remains, and when the window resets. A Quota is a different
/// Metric from a Balance and is never displayed as money.
struct QuotaSnapshot: Codable, Equatable, Sendable {
    let accountID: Account.ID
    let limit: Decimal
    let remaining: Decimal
    let resetAt: Date?
    let fetchedAt: Date
    let packages: [QuotaPackage]?

    init(
        accountID: Account.ID,
        limit: Decimal,
        remaining: Decimal,
        resetAt: Date? = nil,
        fetchedAt: Date,
        packages: [QuotaPackage]? = nil
    ) {
        self.accountID = accountID
        self.limit = limit
        self.remaining = remaining
        self.resetAt = resetAt
        self.fetchedAt = fetchedAt
        self.packages = packages
    }

    var used: Decimal {
        limit - remaining
    }

    /// The fraction of the allowance consumed. A zero or missing limit yields
    /// zero rather than an undefined value; adapters reject malformed limits.
    var usedRatio: Decimal {
        guard limit > 0 else {
            return 0
        }
        return used / limit
    }
}

/// The metric a fetched Snapshot carries. Balance and Quota share the monitor,
/// persistence, and freshness machinery but remain distinct Metric kinds.
enum AccountSnapshot: Codable, Equatable, Sendable {
    case balance(BalanceSnapshot)
    case quota(QuotaSnapshot)

    var accountID: Account.ID {
        switch self {
        case let .balance(snapshot): snapshot.accountID
        case let .quota(snapshot): snapshot.accountID
        }
    }

    var fetchedAt: Date {
        switch self {
        case let .balance(snapshot): snapshot.fetchedAt
        case let .quota(snapshot): snapshot.fetchedAt
        }
    }

    /// Balance snapshots keep the Provider's availability flag. Quota
    /// snapshots are always available; Health, not availability, decides
    /// whether the remaining allowance is critical.
    var isAvailable: Bool {
        switch self {
        case let .balance(snapshot): snapshot.isAvailable
        case .quota: true
        }
    }

    /// The v1 UI reads this accessor so Balance rows render exactly as before.
    var balanceSnapshot: BalanceSnapshot? {
        guard case let .balance(snapshot) = self else {
            return nil
        }
        return snapshot
    }

    var quotaSnapshot: QuotaSnapshot? {
        guard case let .quota(snapshot) = self else {
            return nil
        }
        return snapshot
    }
}

extension AccountSnapshot {
    private enum CodingKeys: String, CodingKey {
        case kind
    }

    private enum Kind: String, Codable {
        case balance
        case quota
    }

    /// Decodes v1 records that have no `kind` key as Balance snapshots.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decodeIfPresent(Kind.self, forKey: .kind) {
        case .quota:
            self = .quota(try QuotaSnapshot(from: decoder))
        case .balance, .none:
            self = .balance(try BalanceSnapshot(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .balance(snapshot):
            try container.encode(Kind.balance, forKey: .kind)
            try snapshot.encode(to: encoder)
        case let .quota(snapshot):
            try container.encode(Kind.quota, forKey: .kind)
            try snapshot.encode(to: encoder)
        }
    }
}
