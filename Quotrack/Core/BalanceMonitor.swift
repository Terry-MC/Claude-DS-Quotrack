import Foundation
import Observation

/// One Account's row state as the panel observes it.
struct BalanceRow: Identifiable, Equatable, Sendable {
    let account: Account
    let snapshot: BalanceSnapshot?
    let status: SnapshotStatus?
    let error: BalanceProviderError?

    init(
        account: Account,
        snapshot: BalanceSnapshot?,
        status: SnapshotStatus?,
        error: BalanceProviderError? = nil
    ) {
        self.account = account
        self.snapshot = snapshot
        self.status = status
        self.error = error
    }

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
    private var provider: any BalanceProvider
    private var accounts: [Account]
    private let pollingInterval: TimeInterval
    private let now: @Sendable () -> Date
    private(set) var rows: [BalanceRow]

    init(
        provider: any BalanceProvider,
        accounts: [Account],
        pollingInterval: TimeInterval = 5 * 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = provider
        self.accounts = accounts
        self.pollingInterval = pollingInterval
        self.now = now
        self.rows = accounts.map { BalanceRow(account: $0, snapshot: nil, status: nil) }
    }

    init(
        dataSource: BalanceDataSource,
        pollingInterval: TimeInterval = 5 * 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = dataSource.provider
        self.accounts = dataSource.accounts
        self.pollingInterval = pollingInterval
        self.now = now
        self.rows = dataSource.accounts.map { BalanceRow(account: $0, snapshot: nil, status: nil) }
    }

    /// Swaps only the Accounts and Provider adapter. The monitor, its polling
    /// behavior, and the UI stay exactly the same.
    func switchDataSource(_ dataSource: BalanceDataSource) async {
        provider = dataSource.provider
        accounts = dataSource.accounts
        rows = accounts.map { BalanceRow(account: $0, snapshot: nil, status: nil) }
        await refresh()
    }

    func refresh() async {
        for account in accounts {
            do {
                apply(try await provider.fetchBalance(for: account))
            } catch let error as BalanceProviderError {
                apply(error, for: account)
            } catch {
                apply(.unknown, for: account)
            }
        }
    }

    private func apply(_ snapshot: BalanceSnapshot) {
        guard let index = rows.firstIndex(where: { $0.account.id == snapshot.accountID }) else {
            return
        }
        rows[index] = BalanceRow(
            account: rows[index].account,
            snapshot: snapshot,
            status: status(for: snapshot)
        )
    }

    private func status(for snapshot: BalanceSnapshot) -> SnapshotStatus {
        guard snapshot.isAvailable else {
            return .unavailable
        }
        let age = now().timeIntervalSince(snapshot.fetchedAt)
        return age > 3 * pollingInterval ? .stale : .fresh
    }

    private func apply(_ error: BalanceProviderError, for account: Account) {
        guard let index = rows.firstIndex(where: { $0.account.id == account.id }) else {
            return
        }
        rows[index] = BalanceRow(
            account: rows[index].account,
            snapshot: rows[index].snapshot,
            status: .error,
            error: error
        )
    }
}
