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

    /// Delays after consecutive failures: 1, 2, 5, then 15 minutes, capped.
    static let backoffDelays: [TimeInterval] = [60, 120, 300, 900]

    /// One Account's independent automatic-refresh schedule.
    private struct AccountSchedule {
        var consecutiveFailures = 0
        var nextAutomaticAttemptAt: Date
    }

    private var provider: any BalanceProvider
    private var accounts: [Account]
    private var configuredPollingInterval: TimeInterval
    private let clock: any PollingClock
    private let now: @Sendable () -> Date
    private let sleepWakeObserver: any SleepWakeObserving
    @ObservationIgnored private let limiter = FetchLimiter(
        capacity: LiveBalanceMonitor.maxConcurrentFetches
    )
    @ObservationIgnored private var schedules: [Account.ID: AccountSchedule]
    private var pollingTask: Task<Void, Never>?
    private var isPollingActive = false
    private var isSleeping = false
    private(set) var rows: [BalanceRow]

    var pollingInterval: TimeInterval {
        get { configuredPollingInterval }
        set {
            guard newValue != configuredPollingInterval else {
                return
            }
            configuredPollingInterval = newValue
            let now = now()
            for account in accounts {
                guard var schedule = schedules[account.id],
                      schedule.consecutiveFailures == 0 else {
                    continue
                }
                schedule.nextAutomaticAttemptAt = now.addingTimeInterval(newValue)
                schedules[account.id] = schedule
            }
            refreshStatuses(at: now)
            guard isPollingActive, !isSleeping else {
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
        now: (@Sendable () -> Date)? = nil,
        sleepWakeObserver: any SleepWakeObserving = NoopSleepWakeObserver()
    ) {
        self.provider = provider
        self.accounts = accounts
        self.configuredPollingInterval = pollingInterval
        self.clock = clock
        self.now = now ?? { clock.now }
        self.sleepWakeObserver = sleepWakeObserver
        self.rows = accounts.map { BalanceRow(account: $0, snapshot: nil, status: nil) }
        let firstAttempt = clock.now.addingTimeInterval(pollingInterval)
        self.schedules = Dictionary(
            uniqueKeysWithValues: accounts.map {
                ($0.id, AccountSchedule(nextAutomaticAttemptAt: firstAttempt))
            }
        )
    }

    convenience init(
        dataSource: BalanceDataSource,
        pollingInterval: TimeInterval = LiveBalanceMonitor.defaultPollingInterval,
        clock: any PollingClock = SystemPollingClock(),
        now: (@Sendable () -> Date)? = nil,
        sleepWakeObserver: any SleepWakeObserving = NoopSleepWakeObserver()
    ) {
        self.init(
            provider: dataSource.provider,
            accounts: dataSource.accounts,
            pollingInterval: pollingInterval,
            clock: clock,
            now: now,
            sleepWakeObserver: sleepWakeObserver
        )
    }

    /// Starts the automatic refresh loop. The first fetch happens after one
    /// Polling Interval; launch-time and manual refreshes are separate.
    func startPolling() {
        guard !isPollingActive else {
            return
        }
        isPollingActive = true
        isSleeping = false
        sleepWakeObserver.start { [weak self] event in
            self?.handleSleepWake(event)
        }
        startPollingTask()
    }

    private func startPollingTask() {
        guard pollingTask == nil, isPollingActive, !isSleeping else {
            return
        }
        pollingTask = Task { [weak self] in
            await self?.runPollingLoop()
        }
    }

    /// Suspends scheduling while the Mac sleeps and refreshes every Account
    /// immediately on wake before automatic polling resumes.
    private func handleSleepWake(_ event: SleepWakeEvent) {
        switch event {
        case .willSleep:
            guard isPollingActive else {
                return
            }
            isSleeping = true
            pollingTask?.cancel()
            pollingTask = nil
        case .didWake:
            guard isPollingActive else {
                return
            }
            isSleeping = false
            Task { [weak self] in
                guard let self else {
                    return
                }
                await self.refresh()
                guard self.isPollingActive, !self.isSleeping else {
                    return
                }
                self.startPollingTask()
            }
        }
    }

    /// Sleeps until the earliest Account is due or the earliest Snapshot
    /// crosses its Stale threshold, whichever comes first. Each Account's
    /// backoff deadline is included, so retries happen on time without a busy
    /// loop.
    private func runPollingLoop() async {
        while !Task.isCancelled {
            let now = now()
            refreshStatuses(at: now)

            let dueAccounts = accountsDue(at: now)
            if !dueAccounts.isEmpty {
                await refreshAccounts(dueAccounts)
                continue
            }

            let deadline = nextScheduledDeadline(after: now)
            let delay = max(deadline.timeIntervalSince(now), 0)
            do {
                try await clock.sleep(for: .seconds(delay))
            } catch {
                return
            }
        }
    }

    private func accountsDue(at date: Date) -> [Account] {
        accounts.filter { account in
            guard let schedule = schedules[account.id] else {
                return true
            }
            return schedule.nextAutomaticAttemptAt <= date
        }
    }

    private func nextScheduledDeadline(after date: Date) -> Date {
        var deadlines = accounts.compactMap { schedules[$0.id]?.nextAutomaticAttemptAt }
        for row in rows {
            guard let snapshot = row.snapshot, snapshot.isAvailable else {
                continue
            }
            let staleAt = snapshot.fetchedAt.addingTimeInterval(3 * pollingInterval)
            if staleAt > date {
                deadlines.append(staleAt)
            }
        }
        return deadlines.min() ?? date.addingTimeInterval(pollingInterval)
    }

    func stopPolling() {
        isPollingActive = false
        isSleeping = false
        pollingTask?.cancel()
        pollingTask = nil
        sleepWakeObserver.stop()
    }

    /// Applies an interval change to the pending wait instead of waiting out
    /// the previous interval first.
    private func restartPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        startPollingTask()
    }

    /// Swaps only the Accounts and Provider adapter. The monitor, its polling
    /// behavior, and the UI stay exactly the same.
    func switchDataSource(_ dataSource: BalanceDataSource) async {
        provider = dataSource.provider
        accounts = dataSource.accounts
        rows = accounts.map { BalanceRow(account: $0, snapshot: nil, status: nil) }
        let firstAttempt = now().addingTimeInterval(pollingInterval)
        schedules = Dictionary(
            uniqueKeysWithValues: accounts.map {
                ($0.id, AccountSchedule(nextAutomaticAttemptAt: firstAttempt))
            }
        )
        await refresh()
    }

    /// Refreshes every Account concurrently, bounded by the global fetch cap.
    /// Manual refreshes bypass any Account's pending backoff.
    func refresh() async {
        await refreshAccounts(accounts)
    }

    /// Refreshes exactly one Account, sharing the same fetch cap as polling.
    /// A manual refresh bypasses that Account's pending backoff.
    func refresh(accountID: Account.ID) async {
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            return
        }
        await refreshAccounts([account])
    }

    private func refreshAccounts(_ accountsToRefresh: [Account]) async {
        let provider = self.provider
        let limiter = self.limiter
        await withTaskGroup(of: FetchResult.self) { group in
            for account in accountsToRefresh {
                group.addTask {
                    await Self.fetch(account, using: provider, limiter: limiter)
                }
            }
            for await result in group {
                apply(result)
            }
        }
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
            recordSuccess(for: result.account)
        case let .failure(error):
            apply(error, for: result.account)
            recordFailure(error, for: result.account)
        case .cancelled:
            break
        }
    }

    /// A successful refresh clears any backoff and returns the Account to the
    /// normal Polling Interval.
    private func recordSuccess(for account: Account) {
        schedules[account.id] = AccountSchedule(
            nextAutomaticAttemptAt: now().addingTimeInterval(pollingInterval)
        )
    }

    /// Failures back off per Account; a Provider-supplied Retry-After takes
    /// precedence over the normal 1, 2, 5, 15 minute schedule.
    private func recordFailure(_ error: BalanceProviderError, for account: Account) {
        var schedule = schedules[account.id]
            ?? AccountSchedule(nextAutomaticAttemptAt: now())
        schedule.consecutiveFailures += 1
        let delay = error.retryAfter
            ?? Self.backoffDelay(forFailureCount: schedule.consecutiveFailures)
        schedule.nextAutomaticAttemptAt = now().addingTimeInterval(delay)
        schedules[account.id] = schedule
    }

    private static func backoffDelay(forFailureCount count: Int) -> TimeInterval {
        let index = min(max(count - 1, 0), backoffDelays.count - 1)
        return backoffDelays[index]
    }

    private func apply(_ snapshot: BalanceSnapshot) {
        guard let index = rows.firstIndex(where: { $0.account.id == snapshot.accountID }) else {
            return
        }
        rows[index] = BalanceRow(
            account: rows[index].account,
            snapshot: snapshot,
            status: status(for: snapshot, error: nil, at: now())
        )
    }

    private func apply(_ error: BalanceProviderError, for account: Account) {
        guard let index = rows.firstIndex(where: { $0.account.id == account.id }) else {
            return
        }
        rows[index] = BalanceRow(
            account: rows[index].account,
            snapshot: rows[index].snapshot,
            status: status(for: rows[index].snapshot, error: error, at: now()),
            error: error
        )
    }

    /// Re-derives freshness from Snapshot age, so a row becomes Stale as time
    /// passes even when no fetch succeeds.
    private func refreshStatuses(at now: Date) {
        var updated = rows
        var changed = false
        for index in updated.indices {
            let row = updated[index]
            let newStatus = status(for: row.snapshot, error: row.error, at: now)
            guard newStatus != row.status else {
                continue
            }
            updated[index] = BalanceRow(
                account: row.account,
                snapshot: row.snapshot,
                status: newStatus,
                error: row.error
            )
            changed = true
        }
        if changed {
            rows = updated
        }
    }

    /// A Snapshot older than three Polling Intervals is Stale regardless of the
    /// last fetch outcome; the last known Balance stays visible. Before that
    /// threshold, an error is surfaced as an error.
    private func status(
        for snapshot: BalanceSnapshot?,
        error: BalanceProviderError?,
        at now: Date
    ) -> SnapshotStatus? {
        guard let snapshot else {
            return error == nil ? nil : .error
        }
        guard snapshot.isAvailable else {
            return .unavailable
        }
        let age = now.timeIntervalSince(snapshot.fetchedAt)
        if age >= 3 * pollingInterval {
            return .stale
        }
        return error == nil ? .fresh : .error
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
