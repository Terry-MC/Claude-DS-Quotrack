import Foundation
import Testing

/// A v1 SiliconFlow Account must remain readable, render as unsupported, stop
/// polling, and stay deletable. Its credential must never reach an adapter.
@MainActor
struct UnsupportedProviderTests {
    @Test
    func aV1SiliconFlowAccountLoadsFromAccountsJSONAsUnsupported() throws {
        let directory = try makeLegacyAccountDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let account = try #require(
            FileSnapshotStore(directoryURL: directory).loadAccounts().first
        )

        #expect(account.id == LegacyAccountFixtures.siliconFlowAccountID)
        #expect(account.provider == .siliconFlow)
        #expect(account.region == .domestic)
        #expect(account.kind == .balance)
        #expect(account.warningThreshold == Decimal(string: "10.5"))
        #expect(!account.provider.isSupported)
    }

    @Test
    func refreshFetchesOnlySupportedAccountsAndShowsTheUnsupportedState() async throws {
        let legacy = legacyAccount()
        let supported = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户"
        )
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [legacy, supported],
            now: { fixedNow }
        )

        await monitor.refresh()

        #expect(provider.fetchedAccountIDs == [supported.id])
        let row = try #require(monitor.rows.first { $0.id == legacy.id })
        #expect(row.status == .unsupported)
        #expect(row.snapshot == nil)
        #expect(row.error == nil)

        let viewState = BalanceRowPresentation.viewState(for: row, now: fixedNow)
        #expect(viewState.status == .unsupported)
        #expect(viewState.statusText == UIStrings.unsupportedProviderState)
        #expect(viewState.balanceText == "—")
        #expect(viewState.updatedText == "—")
        #expect(viewState.tone == .unsupported)
    }

    @Test
    func manualRefreshOfALegacyAccountDoesNotFetchIt() async {
        let provider = RecordingBalanceProvider(snapshot: makeSnapshot)
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [legacyAccount()],
            now: { fixedNow }
        )

        await monitor.refresh(accountID: LegacyAccountFixtures.siliconFlowAccountID)

        #expect(provider.fetchedAccountIDs.isEmpty)
        #expect(monitor.rows.first?.status == .unsupported)
    }

    @Test(.timeLimit(.minutes(1)))
    func pollingNeverFetchesALegacyAccount() async throws {
        let start = fixedNow
        let clock = TestPollingClock(now: start)
        let legacy = legacyAccount()
        let supported = Account(
            id: UUID(),
            provider: .deepSeek,
            label: "个人账户"
        )
        let provider = RecordingBalanceProvider { account in
            BalanceSnapshot(
                accountID: account.id,
                balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
                fetchedAt: clock.now,
                isAvailable: true
            )
        }
        let monitor = LiveBalanceMonitor(
            provider: provider,
            accounts: [legacy, supported],
            pollingInterval: 300,
            clock: clock
        )
        monitor.startPolling()
        defer { monitor.stopPolling() }

        await clock.waitForSleepCount(1)
        #expect(clock.nextSleepDeadline == start.addingTimeInterval(300))

        clock.advance(by: 300)
        await provider.waitForStartedCount(1)
        await clock.waitForSleepCount(2)

        #expect(provider.fetchedAccountIDs == [supported.id])
        let row = try #require(monitor.rows.first { $0.id == legacy.id })
        #expect(row.status == .unsupported)
    }

    @Test
    func theLiveDataSourceNeverSendsALegacyCredentialToTheNetwork() async {
        let account = legacyAccount()
        let credentials = InMemoryCredentialStore(
            credentials: [account.id: "sk-legacy-siliconflow"]
        )
        let transport = StubHTTPTransport(
            response: .json(body: SiliconFlowFixtures.domesticSuccess)
        )
        let store = InMemorySnapshotStore(accounts: [account])
        let dataSource = BalanceDataSource.make(
            mode: .live,
            store: store,
            credentialStore: credentials,
            transport: transport
        )
        let monitor = LiveBalanceMonitor(
            dataSource: dataSource,
            now: { fixedNow }
        )

        await monitor.refresh()

        #expect(transport.requests.isEmpty)
        #expect(monitor.rows.first?.status == .unsupported)
    }

    @Test
    func deletingALegacyAccountRemovesItsKeychainItemAndPersistedSnapshot() throws {
        let directory = try makeLegacyAccountDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileSnapshotStore(directoryURL: directory)
        try store.saveSnapshot(LegacyAccountFixtures.snapshot(fetchedAt: fixedNow))
        let credentials = InMemoryCredentialStore(
            credentials: [
                LegacyAccountFixtures.siliconFlowAccountID: "sk-legacy-siliconflow",
            ]
        )
        let manager = AccountManager(store: store, credentialStore: credentials)
        let account = try #require(manager.accounts.first)
        #expect(account.provider == .siliconFlow)

        try manager.deleteAccount(id: account.id)

        #expect(manager.accounts.isEmpty)
        #expect(store.loadAccounts().isEmpty)
        #expect(store.loadSnapshots().isEmpty)
        #expect(try credentials.credential(for: account.id) == nil)
    }

    @Test
    func anUnsupportedRowDoesNotRaiseTheAggregateState() {
        let row = BalanceRow(
            account: legacyAccount(),
            snapshot: nil,
            status: .unsupported
        )

        #expect(BalanceRowPresentation.tone(for: row) == .unsupported)
        #expect(AggregateBalanceState.derive(from: [row]) == .normal)
    }

    private func legacyAccount() -> Account {
        Account(
            id: LegacyAccountFixtures.siliconFlowAccountID,
            provider: .siliconFlow,
            region: .domestic,
            label: "SiliconFlow 国内",
            warningThreshold: Decimal(string: "10.5")
        )
    }

    private func makeLegacyAccountDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "QuotrackLegacyAccount-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try Data(LegacyAccountFixtures.accountsJSON.utf8).write(
            to: directory.appendingPathComponent("accounts.json")
        )
        return directory
    }
}

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

private func makeSnapshot(for account: Account) -> BalanceSnapshot {
    BalanceSnapshot(
        accountID: account.id,
        balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
        fetchedAt: fixedNow,
        isAvailable: true
    )
}
