import Foundation
import Testing

@MainActor
struct MockModeTests {
    @Test
    func mockDataSourceShowsEveryProviderInCreationOrder() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dataSource = BalanceDataSource.mock(now: now)
        let monitor = LiveBalanceMonitor(dataSource: dataSource)

        await monitor.refresh()

        #expect(monitor.rows.map(\.account) == dataSource.accounts)
        let providers = Set(monitor.rows.map(\.account.provider.rawValue))
        #expect(providers == Set(["deepSeek", "moonshot", "siliconFlow", "openRouter"]))

        let deepSeekRows = monitor.rows.filter { $0.account.provider == .deepSeek }
        #expect(deepSeekRows.count >= 2)

        let legacyRow = try #require(
            monitor.rows.first {
                $0.account.provider == .siliconFlow
                    && $0.account.label == "SiliconFlow 国内"
            }
        )
        #expect(legacyRow.status == .unsupported)
        #expect(legacyRow.snapshot == nil)
        #expect(
            BalanceRowPresentation.viewState(for: legacyRow, now: now)
                .statusText == UIStrings.unsupportedProviderState
        )
    }

    @Test
    func mockDataSourceShowsEveryTypedErrorCategory() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let monitor = LiveBalanceMonitor(dataSource: .mock(now: now))

        await monitor.refresh()

        let errorRows = monitor.rows.filter { $0.status == .error }
        let expectedErrors = Set(BalanceProviderError.allCases)
            .subtracting([.unsupportedAccountKind])
        #expect(Set(errorRows.compactMap(\.error)) == expectedErrors)
        #expect(errorRows.allSatisfy { $0.snapshot == nil })
    }

    @Test
    func mockDataSourceMarksAnOldSnapshotStale() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let monitor = LiveBalanceMonitor(
            dataSource: .mock(now: now),
            pollingInterval: 300,
            now: { now }
        )

        await monitor.refresh()

        let staleRows = monitor.rows.filter { $0.status == .stale }
        #expect(staleRows.count == 1)
        let staleRow = try #require(staleRows.first)
        #expect(staleRow.snapshot?.fetchedAt == now.addingTimeInterval(-1_200))
        #expect(staleRow.snapshot != nil)
        #expect(staleRow.error == nil)
    }

    @Test
    func mockDataSourceIncludesRateLimitsWithAndWithoutRetryAfter() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let monitor = LiveBalanceMonitor(
            dataSource: .mock(now: now),
            pollingInterval: 300,
            now: { now }
        )

        await monitor.refresh()

        let rateLimitRows = monitor.rows.filter { $0.error?.category == .rateLimit }
        #expect(rateLimitRows.count >= 2)
        #expect(rateLimitRows.contains { $0.error?.retryAfter == nil })
        #expect(rateLimitRows.contains { $0.error?.retryAfter == 120 })
    }

    @Test
    func headerCountsHealthSeverities() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let monitor = LiveBalanceMonitor(
            dataSource: .mock(now: now),
            pollingInterval: 300,
            now: { now }
        )

        await monitor.refresh()

        let header = PanelHeaderPresentation.viewState(for: monitor.rows)
        #expect(header.healthyCount == 0)
        #expect(header.warningCount == 2)
        #expect(header.criticalCount == 0)
        #expect(header.errorCount == 7)
        #expect(header.healthyText == "正常 0")
        #expect(header.warningText == "预警 2")
        #expect(header.errorText == "错误 7")
    }

    @Test
    func switchingToMockDataSourceReplacesRowsUsingTheNewProvider() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = Account(id: UUID(), provider: .deepSeek, label: "真实账户")
        let monitor = LiveBalanceMonitor(
            provider: StubProvider(error: .authentication),
            accounts: [account],
            pollingInterval: 300,
            now: { now }
        )
        await monitor.refresh()
        #expect(monitor.rows.count == 1)
        #expect(monitor.rows.first?.status == .error)

        let mockSource = BalanceDataSource.mock(now: now)
        await monitor.switchDataSource(mockSource)

        let mockRows = monitor.rows
        #expect(mockRows.count > 1)
        #expect(mockRows.map(\.account) == mockSource.accounts)
        #expect(mockRows.contains { $0.status == .fresh })
        #expect(mockRows.contains { $0.status == .error })
        #expect(mockRows.contains { $0.status == .stale })
    }

    @Test
    func mockDataSourceIncludesALowBalanceAccount() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let monitor = LiveBalanceMonitor(
            dataSource: .mock(now: now),
            pollingInterval: 300,
            now: { now }
        )

        await monitor.refresh()

        let lowBalanceRow = try #require(
            monitor.rows.first { $0.account.label == "工作账户" }
        )
        #expect(
            lowBalanceRow.balanceSnapshot?.balance
                == Balance(amount: Decimal(string: "0.80")!, currency: .cny)
        )
        #expect(lowBalanceRow.status == .fresh)
        #expect(lowBalanceRow.account.warningThreshold == Decimal(string: "5.00"))
        #expect(BalanceRowPresentation.tone(for: lowBalanceRow) == .warning)
    }

    @Test
    func mockDataSourceProvidesBreakdownsForExpandedRowsWhenAvailable() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let monitor = LiveBalanceMonitor(
            dataSource: .mock(now: now),
            pollingInterval: 300,
            now: { now }
        )

        await monitor.refresh()

        let personalRow = try #require(
            monitor.rows.first { $0.account.label == "个人账户" }
        )
        #expect(personalRow.balanceSnapshot?.breakdown == [
            BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "28.40")!),
            BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "100.00")!),
        ])
        let detail = BalanceRowPresentation.detailViewState(for: personalRow)
        #expect(detail.breakdown.map(\.label) == ["赠送余额", "充值余额"])

        let balancedRows = monitor.rows.filter { $0.balanceSnapshot != nil }
        #expect(balancedRows.contains { $0.balanceSnapshot?.breakdown == nil })
        #expect(balancedRows.filter { $0.balanceSnapshot?.breakdown != nil }.count >= 3)
    }

    @Test
    func launchModeSelectsFixtureAccountsOnlyInMockMode() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let mockSource = BalanceDataSource.make(mode: .mock, now: now)
        let liveSource = BalanceDataSource.make(mode: .live, now: now)

        #expect(mockSource.accounts.count == 12)
        #expect(Set(mockSource.accounts.map(\.provider)) == Set(Provider.allCases))
        #expect(liveSource.accounts.isEmpty)
    }
}

private struct StubProvider: BalanceProvider {
    let error: BalanceProviderError

    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        throw error
    }
}
