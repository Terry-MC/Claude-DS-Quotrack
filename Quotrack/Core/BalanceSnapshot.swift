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

/// The result of one balance query for one Account at one point in time.
struct BalanceSnapshot: Codable, Equatable, Sendable {
    let accountID: Account.ID
    let balance: Balance
    let fetchedAt: Date
    let isAvailable: Bool
}
