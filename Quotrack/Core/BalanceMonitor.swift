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
    var pollingInterval: TimeInterval { get set }
    func startPolling()
    func stopPolling()
    func refresh() async
    func refresh(accountID: Account.ID) async
}

extension BalanceMonitor {
    /// Refreshes one Account. Its identity is the Account UUID, so callers
    /// holding a stale Account value still address the right row.
    func refresh(account: Account) async {
        await refresh(accountID: account.id)
    }
}

@MainActor
@Observable
final class LiveBalanceMonitor: BalanceMonitor {
    /// The Polling Interval used when the caller does not configure one.
    static let defaultPollingInterval: TimeInterval = 5 * 60

    private var provider: any BalanceProvider
    private var accounts: [Account]
    private var configuredPollingInterval: TimeInterval
    private let clock: any PollingClock
    private let now: @Sendable () -> Date
    private var pollingTask: Task<Void, Never>?
    private(set) var rows: [BalanceRow]

    var pollingInterval: TimeInterval {
        get { configuredPollingInterval }
        set {
            guard newValue != configuredPollingInterval else {
                return
            }
            configuredPollingInterval = newValue
            guard pollingTask != nil else {
                return
            }
            restartPolling()
        }
    }

    init(
        provider: any BalanceProvider,
        accounts: [Account],
        pollingInterval: TimeInterval = LiveBalanceMonitor.defaultPollingInterval,
        clock: any PollingClock = SystemPollingClock(),
        now: (@Sendable () -> Date)? = nil
    ) {
        self.provider = provider
        self.accounts = accounts
        self.configuredPollingInterval = pollingInterval
        self.clock = clock
        self.now = now ?? { clock.now }
        self.rows = accounts.map { BalanceRow(account: $0, snapshot: nil, status: nil) }
    }

    convenience init(
        dataSource: BalanceDataSource,
        pollingInterval: TimeInterval = LiveBalanceMonitor.defaultPollingInterval,
        clock: any PollingClock = SystemPollingClock(),
        now: (@Sendable () -> Date)? = nil
    ) {
        self.init(
            provider: dataSource.provider,
            accounts: dataSource.accounts,
            pollingInterval: pollingInterval,
            clock: clock,
            now: now
        )
    }

    /// Starts the periodic refresh loop. The first fetch happens after one
    /// Polling Interval; launch-time and manual refreshes are separate.
    func startPolling() {
        guard pollingTask == nil else {
            return
        }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                do {
                    try await self.clock.sleep(for: .seconds(self.pollingInterval))
                } catch {
                    return
                }
                if Task.isCancelled {
                    return
                }
                await self.refresh()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Applies an interval change to the pending wait instead of waiting out
    /// the previous interval first.
    private func restartPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        startPolling()
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
            await refreshOne(account)
        }
    }

    func refresh(accountID: Account.ID) async {
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            return
        }
        await refreshOne(account)
    }

    private func refreshOne(_ account: Account) async {
        do {
            apply(try await provider.fetchBalance(for: account))
        } catch let error as BalanceProviderError {
            apply(error, for: account)
        } catch {
            apply(.unknown, for: account)
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
