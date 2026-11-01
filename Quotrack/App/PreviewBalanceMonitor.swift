import Foundation
import Observation

/// A mutable monitor fake for SwiftUI previews. It lets previews show fresh,
/// Stale, error, and empty states without polling, a network, or a Keychain.
@MainActor
@Observable
final class PreviewBalanceMonitor: BalanceMonitor {
    var rows: [BalanceRow]
    var pollingInterval: TimeInterval = LiveBalanceMonitor.defaultPollingInterval

    var aggregateState: AggregateBalanceState {
        AggregateBalanceState.derive(from: rows)
    }

    init(rows: [BalanceRow] = []) {
        self.rows = rows
    }

    func startPolling() {}

    func stopPolling() {}

    func refresh() async {}

    func refresh(accountID: Account.ID) async {}
}
