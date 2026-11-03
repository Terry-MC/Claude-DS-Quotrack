import Foundation
import Testing

@MainActor
struct PersistenceLaunchTests {
    @Test
    func persistedSnapshotIsShownBeforeAnyRefresh() async throws {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-60),
            isAvailable: true
        )
        let store = InMemorySnapshotStore(snapshots: [account.id: snapshot])
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)

        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            store: store,
            pollingInterval: 300,
            now: { now }
        )

        #expect(provider.startedCount == 0)
        let row = try #require(monitor.rows.first)
        #expect(row.balanceSnapshot == snapshot)
        #expect(row.status == .fresh)
        #expect(row.error == nil)
    }

    @Test
    func persistedSnapshotOlderThanThreeIntervalsIsStaleOnLaunch() throws {
        let account = Account(id: UUID(), provider: .moonshot, label: "Kimi 主账号")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "12.00")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-(3 * 300) - 1),
            isAvailable: true
        )
        let store = InMemorySnapshotStore(snapshots: [account.id: snapshot])
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)

        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            store: store,
            pollingInterval: 300,
            now: { now }
        )

        let row = try #require(monitor.rows.first)
        #expect(row.balanceSnapshot == snapshot)
        #expect(row.status == .stale)
        #expect(row.error == nil)
    }

    @Test
    func persistedSnapshotExactlyThreeIntervalsOldIsStillFresh() throws {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "5.00")!, currency: .usd),
            fetchedAt: now.addingTimeInterval(-(3 * 300)),
            isAvailable: true
        )
        let store = InMemorySnapshotStore(snapshots: [account.id: snapshot])

        let monitor = LiveBalanceMonitor(
            provider: RecordingBalanceProvider(snapshot: makeSnapshot),
            accounts: [account],
            store: store,
            pollingInterval: 300,
            now: { now }
        )

        let row = try #require(monitor.rows.first)
        #expect(row.status == .fresh)
    }

    @Test
    func successfulRefreshPersistsTheLastSnapshot() async throws {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let store = InMemorySnapshotStore()
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [account],
            store: store,
            pollingInterval: 300,
            now: { now }
        )

        await monitor.refresh()

        #expect(store.loadBalanceSnapshots() == [account.id: makeSnapshot(for: account)])
    }

    @Test
    func failedRefreshKeepsTheLastSuccessfulPersistedSnapshot() async throws {
        let account = Account(id: UUID(), provider: .openRouter, label: "管理账户")
        let persisted = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "18.75")!, currency: .usd),
            fetchedAt: now.addingTimeInterval(-60),
            isAvailable: true
        )
        let store = InMemorySnapshotStore(snapshots: [account.id: persisted])
        let monitor = LiveBalanceMonitor(
            provider: FailingPersistenceProvider(error: .network),
            accounts: [account],
            store: store,
            pollingInterval: 300,
            now: { now }
        )

        await monitor.refresh()

        let row = try #require(monitor.rows.first)
        #expect(row.status == .error)
        #expect(row.error == .network)
        #expect(row.balanceSnapshot == persisted)
        #expect(store.loadBalanceSnapshots() == [account.id: persisted])
    }

    @Test
    func accountAndSnapshotSurviveRelaunchAndShowBeforeRefresh() async throws {
        let directory = try makeTemporaryPersistenceDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let firstLaunchStore = FileSnapshotStore(directoryURL: directory)
        try firstLaunchStore.saveAccounts([account])
        let firstLaunch = LiveBalanceMonitor(
            provider: RecordingBalanceProvider(snapshot: makeSnapshot),
            accounts: firstLaunchStore.loadAccounts(),
            store: firstLaunchStore,
            pollingInterval: 300,
            now: { now }
        )
        await firstLaunch.refresh()

        let relaunchStore = FileSnapshotStore(directoryURL: directory)
        let relaunchProvider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let relaunched = LiveBalanceMonitor(
            provider: relaunchProvider,
            accounts: relaunchStore.loadAccounts(),
            store: relaunchStore,
            pollingInterval: 300,
            now: { now.addingTimeInterval(60) }
        )

        #expect(relaunchProvider.startedCount == 0)
        let row = try #require(relaunched.rows.first)
        #expect(row.account == account)
        #expect(row.balanceSnapshot == makeSnapshot(for: account))
        #expect(row.status == .fresh)
    }

    @Test
    func persistedAccountsAreLoadedIntoTheLiveDataSource() throws {
        let account = Account(id: UUID(), provider: .siliconFlow, label: "SiliconFlow 国内")
        let snapshot = BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Decimal(string: "15.00")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-120),
            isAvailable: true
        )
        let store = InMemorySnapshotStore(
            accounts: [account],
            snapshots: [account.id: snapshot]
        )

        let dataSource = BalanceDataSource.make(mode: .live, store: store)
        let monitor = LiveBalanceMonitor(
            dataSource: dataSource,
            store: store,
            pollingInterval: 300,
            now: { now }
        )

        #expect(dataSource.accounts == [account])
        #expect(monitor.rows.map(\.account) == [account])
        #expect(monitor.rows.first?.balanceSnapshot == snapshot)
        #expect(monitor.rows.first?.status == .unsupported)
    }

    @Test
    func mockModeDoesNotReadOrWritePersistedAccounts() async {
        let realAccount = Account(id: UUID(), provider: .deepSeek, label: "真实账户")
        let persisted = BalanceSnapshot(
            accountID: realAccount.id,
            balance: Balance(amount: Decimal(string: "3.00")!, currency: .cny),
            fetchedAt: now.addingTimeInterval(-60),
            isAvailable: true
        )
        let store = InMemorySnapshotStore(
            accounts: [realAccount],
            snapshots: [realAccount.id: persisted]
        )

        let mockSource = BalanceDataSource.make(mode: .mock, now: now, store: store)
        let monitor = LiveBalanceMonitor(
            dataSource: mockSource,
            store: nil,
            pollingInterval: 300,
            now: { now }
        )
        await monitor.switchDataSource(.mock(now: now), store: nil)

        #expect(mockSource.accounts.count == 19)
        #expect(!mockSource.accounts.contains { $0.id == realAccount.id })
        #expect(store.loadBalanceSnapshots() == [realAccount.id: persisted])
    }

    @Test
    func persistedSnapshotForADifferentAccountIsIgnored() throws {
        let account = Account(id: UUID(), provider: .deepSeek, label: "个人账户")
        let otherAccount = Account(id: UUID(), provider: .openRouter, label: "OpenRouter")
        let otherSnapshot = BalanceSnapshot(
            accountID: otherAccount.id,
            balance: Balance(amount: Decimal(string: "1.00")!, currency: .usd),
            fetchedAt: now,
            isAvailable: true
        )
        let store = InMemorySnapshotStore(snapshots: [otherAccount.id: otherSnapshot])

        let monitor = LiveBalanceMonitor(
            provider: RecordingBalanceProvider(snapshot: makeSnapshot),
            accounts: [account],
            store: store,
            pollingInterval: 300,
            now: { now }
        )

        let row = try #require(monitor.rows.first)
        #expect(row.snapshot == nil)
        #expect(row.status == nil)
    }
}

private struct FailingPersistenceProvider: BalanceProvider {
    let error: BalanceProviderError

    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        throw error
    }
}

private func makeTemporaryPersistenceDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuotrackPersistenceTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func makeSnapshot(for account: Account) -> BalanceSnapshot {
    BalanceSnapshot(
        accountID: account.id,
        balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
        fetchedAt: now,
        isAvailable: true
    )
}
