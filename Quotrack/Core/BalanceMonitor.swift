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

    /// The global number of Provider fetches allowed in flight at once.
    static let maxConcurrentFetches = 3

    private var provider: any BalanceProvider
    private var accounts: [Account]
    private var configuredPollingInterval: TimeInterval
    private let clock: any PollingClock
    private let now: @Sendable () -> Date
    private var store: (any SnapshotStore)?
    @ObservationIgnored private let limiter = FetchLimiter(
        capacity: LiveBalanceMonitor.maxConcurrentFetches
    )
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
        store: (any SnapshotStore)? = nil,
        pollingInterval: TimeInterval = LiveBalanceMonitor.defaultPollingInterval,
        clock: any PollingClock = SystemPollingClock(),
        now: (@Sendable () -> Date)? = nil
    ) {
        self.provider = provider
        self.accounts = accounts
        self.configuredPollingInterval = pollingInterval
        self.clock = clock
        self.now = now ?? { clock.now }
        self.store = store
        self.rows = []
        self.rows = initialRows(for: accounts, store: store)
    }

    convenience init(
        dataSource: BalanceDataSource,
        store: (any SnapshotStore)? = nil,
        pollingInterval: TimeInterval = LiveBalanceMonitor.defaultPollingInterval,
        clock: any PollingClock = SystemPollingClock(),
        now: (@Sendable () -> Date)? = nil
    ) {
        self.init(
            provider: dataSource.provider,
            accounts: dataSource.accounts,
            store: store,
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

    /// Swaps only the Accounts, Provider adapter, and persistence. The
    /// monitor, its polling behavior, and the UI stay exactly the same. Mock
    /// mode passes `store: nil` so it never writes to the real store.
    func switchDataSource(
        _ dataSource: BalanceDataSource,
        store: (any SnapshotStore)? = nil
    ) async {
        provider = dataSource.provider
        accounts = dataSource.accounts
        self.store = store
        rows = initialRows(for: dataSource.accounts, store: store)
        await refresh()
    }

    /// Persisted Snapshots are shown before the first refresh so a launch is
    /// never blank. Freshness is computed against the configured Polling
    /// Interval, so old Snapshots come back marked Stale.
    private func initialRows(
        for accounts: [Account],
        store: (any SnapshotStore)?
    ) -> [BalanceRow] {
        let persisted = store?.loadSnapshots() ?? [:]
        return accounts.map { account in
            let snapshot = persisted[account.id]
            let matching = snapshot?.accountID == account.id ? snapshot : nil
            return BalanceRow(
                account: account,
                snapshot: matching,
                status: matching.map { status(for: $0) }
            )
        }
    }

    /// Refreshes every Account concurrently, bounded by the global fetch cap.
    /// Results are applied as they arrive, so one slow Account never delays
    /// the rows of the others.
    func refresh() async {
        let accounts = self.accounts
        let provider = self.provider
        let limiter = self.limiter
        await withTaskGroup(of: FetchResult.self) { group in
            for account in accounts {
                group.addTask {
                    await Self.fetch(account, using: provider, limiter: limiter)
                }
            }
            for await result in group {
                apply(result)
            }
        }
    }

    /// Refreshes exactly one Account, sharing the same fetch cap as polling.
    func refresh(accountID: Account.ID) async {
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            return
        }
        let result = await Self.fetch(account, using: provider, limiter: limiter)
        apply(result)
    }

    private nonisolated static func fetch(
        _ account: Account,
        using provider: any BalanceProvider,
        limiter: FetchLimiter
    ) async -> FetchResult {
        do {
            try await limiter.acquire()
        } catch {
            return FetchResult(account: account, outcome: .cancelled)
        }

        if Task.isCancelled {
            await limiter.release()
            return FetchResult(account: account, outcome: .cancelled)
        }

        let outcome: FetchOutcome
        do {
            let snapshot = try await provider.fetchBalance(for: account)
            outcome = .snapshot(snapshot)
        } catch {
            outcome = Task.isCancelled
                ? .cancelled
                : .failure(BalanceProviderError.classify(error))
        }
        await limiter.release()
        return FetchResult(account: account, outcome: outcome)
    }

    private func apply(_ result: FetchResult) {
        switch result.outcome {
        case let .snapshot(snapshot):
            apply(snapshot)
        case let .failure(error):
            apply(error, for: result.account)
        case .cancelled:
            break
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
        // Persistence is best-effort: a disk problem must never turn a
        // successful Balance query into an error for the Account.
        try? store?.saveSnapshot(snapshot)
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

/// What one Provider fetch produced, independent of which Account's task ran.
private enum FetchOutcome: Sendable {
    case snapshot(BalanceSnapshot)
    case failure(BalanceProviderError)
    case cancelled
}

private struct FetchResult: Sendable {
    let account: Account
    let outcome: FetchOutcome
}
