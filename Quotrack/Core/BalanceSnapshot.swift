import Foundation

/// The currency a Balance is reported in. Amounts are never converted.
struct Currency: Codable, Equatable, Sendable {
    let code: String
    let symbol: String

    static let cny = Currency(code: "CNY", symbol: "¥")
    static let usd = Currency(code: "USD", symbol: "$")
}

/// The prepaid credit remaining on an Account, as reported by its Provider.
struct Balance: Codable, Equatable, Sendable {
    let amount: Decimal
    let currency: Currency
}

/// Freshness of a Balance Snapshot. A Snapshot older than its staleness
/// threshold is Stale; an unavailable Account still keeps its Snapshot.
enum SnapshotStatus: String, Sendable, Equatable {
    case fresh
    case stale
    case unavailable
    case error
}

/// One named component of a Balance, such as granted versus topped-up credit.
/// Providers report different components, so the kind is the shared vocabulary
/// and the amount always uses the Snapshot's currency.
struct BalanceBreakdownItem: Codable, Equatable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable, Equatable, CaseIterable {
        case granted
        case toppedUp
        case voucher
        case cash
        case totalCredits
        case usage
    }

    let kind: Kind
    let amount: Decimal

    var id: Kind { kind }
}

/// The result of one balance query for one Account at one point in time.
struct BalanceSnapshot: Codable, Equatable, Sendable {
    let accountID: Account.ID
    let balance: Balance
    let fetchedAt: Date
    let isAvailable: Bool
    /// Optional per-Provider detail. Absent when the Provider reports only a
    /// total, so existing callers and persisted Snapshots stay compatible.
    let breakdown: [BalanceBreakdownItem]?

    init(
        accountID: Account.ID,
        balance: Balance,
        fetchedAt: Date,
        isAvailable: Bool,
        breakdown: [BalanceBreakdownItem]? = nil
    ) {
        self.accountID = accountID
        self.balance = balance
        self.fetchedAt = fetchedAt
        self.isAvailable = isAvailable
        self.breakdown = breakdown
    }
}
