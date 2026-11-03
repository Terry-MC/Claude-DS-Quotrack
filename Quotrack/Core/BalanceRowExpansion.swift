import Foundation

/// Which Account rows are expanded. Keyed by Account identity so expansion
/// survives the Snapshot updates that arrive while polling.
struct BalanceRowExpansion: Equatable, Sendable {
    private(set) var expandedAccountIDs: Set<Account.ID> = []

    func isExpanded(_ accountID: Account.ID) -> Bool {
        expandedAccountIDs.contains(accountID)
    }

    mutating func toggle(_ accountID: Account.ID) {
        if expandedAccountIDs.contains(accountID) {
            expandedAccountIDs.remove(accountID)
        } else {
            expandedAccountIDs.insert(accountID)
        }
    }

    /// Opens one row without collapsing any other. Notification focus uses
    /// this so revealing the affected Account is never a toggle that could
    /// close it.
    mutating func expand(_ accountID: Account.ID) {
        expandedAccountIDs.insert(accountID)
    }
}
