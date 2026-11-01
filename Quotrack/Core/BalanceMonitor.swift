import Foundation
import Observation

/// One Account's row state as the panel observes it.
struct BalanceRow: Identifiable, Equatable, Sendable {
    let account: Account
    let snapshot: BalanceSnapshot?
    let status: SnapshotStatus?

    var id: Account.ID { account.id }
}

/// The single observable seam the UI depends on. Polling, backoff, staleness,
/// and persistence live behind this interface.
@MainActor
protocol BalanceMonitor: AnyObject, Observable {
    var rows: [BalanceRow] { get }
    func refresh() async
}

@MainActor
@Observable
final class LiveBalanceMonitor: BalanceMonitor {
    private let provider: any BalanceProvider
    private let accounts: [Account]
    private(set) var rows: [BalanceRow]

    init(provider: any BalanceProvider, accounts: [Account]) {
        self.provider = provider
        self.accounts = accounts
        self.rows = accounts.map { BalanceRow(account: $0, snapshot: nil, status: nil) }
    }

    func refresh() async {
        for account in accounts {
            guard let snapshot = try? await provider.fetchBalance(for: account) else {
                continue
            }
            apply(snapshot)
        }
    }

    private func apply(_ snapshot: BalanceSnapshot) {
        guard let index = rows.firstIndex(where: { $0.account.id == snapshot.accountID }) else {
            return
        }
        let status: SnapshotStatus = snapshot.isAvailable ? .fresh : .unavailable
        rows[index] = BalanceRow(
            account: rows[index].account,
            snapshot: snapshot,
            status: status
        )
    }
}
