import Foundation
import Testing

/// Provider grouping, per-kind sections, and collapsed summaries. These are
/// pure presentation rules: no monitor, network, or Keychain is involved.
struct ProviderGroupPresentationTests {
    // MARK: Grouping and ordering

    @Test
    func groupsProvidersInCreationOrderAndKeepsAccountsInRowOrder() throws {
        let firstDeepSeek = balanceRow(provider: .deepSeek, label: "个人")
        let moonshot = balanceRow(provider: .moonshot, label: "工作")
        let secondDeepSeek = balanceRow(provider: .deepSeek, label: "备用")
        let openRouter = balanceRow(provider: .openRouter, label: "管理")

        let groups = ProviderGroupPresentation.groups(
            from: [firstDeepSeek, moonshot, secondDeepSeek, openRouter]
        )

        #expect(groups.map(\.provider) == [.deepSeek, .moonshot, .openRouter])
        let deepSeekGroup = try #require(groups.first)
        #expect(deepSeekGroup.sections.count == 1)
        #expect(deepSeekGroup.sections[0].rows.map(\.account.label) == ["个人", "备用"])
        #expect(deepSeekGroup.accountCount == 2)
    }

    @Test
    func noRowsProduceNoProviderGroups() {
        #expect(ProviderGroupPresentation.groups(from: []).isEmpty)
    }

    @Test
    func aSingleAccountProviderHasOneSectionAndOneRow() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [balanceRow(provider: .deepSeek, label: "个人")]
            ).first
        )

        #expect(group.provider == .deepSeek)
        #expect(group.name == "DeepSeek")
        #expect(group.accountCount == 1)
        #expect(group.sections.count == 1)
        #expect(group.sections[0].kind == .balance)
        #expect(group.sections[0].rows.count == 1)
        #expect(group.kindCountText == "充值 1")
    }

    @Test
    func aProviderWithMultipleAccountsShowsEveryAccountInItsSection() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    balanceRow(provider: .openRouter, label: "主账户"),
                    balanceRow(provider: .openRouter, label: "备用账户"),
                ]
            ).first
        )

        #expect(group.accountCount == 2)
        #expect(group.sections[0].accountCount == 2)
        #expect(group.sections[0].rows.map(\.account.label) == ["主账户", "备用账户"])
        #expect(group.kindCountText == "充值 2")
    }

    // MARK: Account Kind sections

    @Test
    func aMoonshotProviderShowsSeparateBalanceAndQuotaSections() throws {
        let moonshot = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    balanceRow(provider: .moonshot, label: "充值一"),
                    quotaRow(label: "Kimi Code", remaining: 60),
                    balanceRow(provider: .moonshot, label: "充值二"),
                ]
            ).first
        )

        #expect(moonshot.sections.map(\.kind) == [.balance, .subscription])
        #expect(moonshot.sections.map(\.title) == ["余额", "额度"])
        #expect(moonshot.sections[0].accountCount == 2)
        #expect(moonshot.sections[1].accountCount == 1)
        #expect(moonshot.sections[0].rows.map(\.account.label) == ["充值一", "充值二"])
        #expect(moonshot.sections[1].rows.map(\.account.label) == ["Kimi Code"])
        #expect(moonshot.kindCountText == "充值 2 · 订阅 1")
        #expect(moonshot.accountCount == 3)
    }

    @Test
    func sectionsFollowKindOrderEvenWhenQuotaRowsComeFirst() throws {
        let moonshot = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    quotaRow(label: "Kimi Code", remaining: 60),
                    balanceRow(provider: .moonshot, label: "充值"),
                ]
            ).first
        )

        #expect(moonshot.sections.map(\.kind) == [.balance, .subscription])
    }

    @Test
    func aProviderOnlyGetsSectionsForKindsItHasAccountsIn() throws {
        let quotaOnly = try #require(
            ProviderGroupPresentation.groups(
                from: [quotaRow(label: "Kimi Code", remaining: 60)]
            ).first
        )

        #expect(quotaOnly.sections.map(\.kind) == [.subscription])
        #expect(quotaOnly.kindCountText == "订阅 1")
    }

    // MARK: Balance totals

    @Test
    func balanceTotalsGroupByCurrencyAndNeverSumAcrossCurrencies() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    balanceRow(
                        provider: .moonshot,
                        currency: .cny,
                        amount: Decimal(string: "20.50")!
                    ),
                    balanceRow(provider: .moonshot, currency: .usd, amount: 5),
                    balanceRow(provider: .moonshot, currency: .cny, amount: 10),
                ]
            ).first
        )
        let section = try #require(group.sections.first)

        #expect(section.balanceTotals.count == 2)
        let cny = try #require(section.balanceTotals.first { $0.currency == .cny })
        let usd = try #require(section.balanceTotals.first { $0.currency == .usd })
        #expect(cny.amount == Decimal(string: "30.50"))
        #expect(cny.amountText == "¥30.50")
        #expect(usd.amount == 5)
        #expect(usd.amountText == "$5.00")
        #expect(section.balanceTotalText == "合计 ¥30.50 · $5.00")
    }

    @Test
    func balanceTotalOrderFollowsFirstAppearanceOfEachCurrency() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    balanceRow(provider: .moonshot, currency: .usd, amount: 1),
                    balanceRow(provider: .moonshot, currency: .cny, amount: 2),
                    balanceRow(provider: .moonshot, currency: .usd, amount: 3),
                ]
            ).first
        )

        #expect(group.sections[0].balanceTotals.map(\.currency) == [.usd, .cny])
        #expect(group.sections[0].balanceTotals[0].amount == 4)
    }

    @Test
    func balanceTotalsNeverIncludeAnotherProvidersAccounts() throws {
        let groups = ProviderGroupPresentation.groups(
            from: [
                balanceRow(provider: .deepSeek, amount: 100),
                balanceRow(provider: .moonshot, amount: 30),
            ]
        )
        let deepSeekTotal = try #require(
            groups.first { $0.provider == .deepSeek }?
                .sections.first?.balanceTotals.first
        )
        let moonshotTotal = try #require(
            groups.first { $0.provider == .moonshot }?
                .sections.first?.balanceTotals.first
        )

        #expect(deepSeekTotal.amount == 100)
        #expect(moonshotTotal.amount == 30)
    }

    @Test
    func unsupportedAccountsAreNotIncludedInBalanceTotals() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    balanceRow(provider: .siliconFlow, amount: 999),
                    balanceRow(provider: .siliconFlow, amount: 1),
                ]
            ).first
        )

        #expect(group.accountCount == 2)
        #expect(group.sections[0].balanceTotals.isEmpty)
        #expect(group.health == .unset)
    }

    @Test
    func quotaSectionsDoNotCarryBalanceTotals() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [quotaRow(label: "Kimi Code", remaining: 60)]
            ).first
        )

        #expect(group.sections[0].balanceTotals.isEmpty)
    }

    // MARK: Quota summary

    @Test
    func quotaSummaryReportsTheWorstRemainingPercentage() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    quotaRow(label: "正常", remaining: 80),
                    quotaRow(label: "预警", remaining: 15),
                    quotaRow(label: "中等", remaining: 50),
                ]
            ).first
        )
        let section = try #require(group.sections.first)

        #expect(section.quotaWorstRemainingPercent == 15)
        #expect(section.quotaWorstRemainingText == "15%")
        #expect(section.quotaWorstRemainingSummaryText == "最低剩余 15%")
    }

    @Test
    func quotaSummaryConvertsEachAccountAgainstItsOwnLimit() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    quotaRow(label: "四十", limit: 200, remaining: 40),
                    quotaRow(label: "十五", limit: 100, remaining: 15),
                ]
            ).first
        )

        #expect(group.sections[0].quotaWorstRemainingPercent == Decimal(string: "15"))
    }

    @Test
    func quotaSummaryKeepsAFractionalWorstPercentage() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    quotaRow(label: "正常", limit: 1000, remaining: 500),
                    quotaRow(label: "小数", limit: 1000, remaining: 135),
                ]
            ).first
        )

        #expect(group.sections[0].quotaWorstRemainingPercent == Decimal(string: "13.5"))
        #expect(group.sections[0].quotaWorstRemainingText == "13.5%")
    }

    @Test
    func quotaSummaryIgnoresAccountsWithoutAQuotaSnapshot() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    quotaRow(label: "未加载", remaining: 0, status: nil),
                    quotaRow(label: "已加载", remaining: 40),
                ]
            ).first
        )

        #expect(group.sections[0].accountCount == 2)
        #expect(group.sections[0].quotaWorstRemainingPercent == 40)
    }

    @Test
    func quotaSummaryIsAbsentWhenNoAccountHasASnapshot() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [quotaRow(label: "未加载", remaining: 0, status: nil)]
            ).first
        )

        #expect(group.sections[0].quotaWorstRemainingPercent == nil)
        #expect(group.sections[0].quotaWorstRemainingText == nil)
    }

    @Test
    func aStaleQuotaStillContributesItsLastKnownPercentage() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    quotaRow(label: "过期", remaining: 12, status: .stale),
                    quotaRow(label: "新鲜", remaining: 60),
                ]
            ).first
        )
        let section = try #require(group.sections.first)

        #expect(section.quotaWorstRemainingPercent == 12)
        #expect(section.staleCount == 1)
    }

    // MARK: Health and counts

    @Test
    func providerHealthIsTheWorstAccountHealth() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    balanceRow(provider: .deepSeek, amount: 50, warning: 10),
                    balanceRow(provider: .deepSeek, amount: 8, warning: 10, critical: 5),
                    balanceRow(provider: .deepSeek, amount: 4, warning: 10, critical: 5),
                ]
            ).first
        )

        #expect(group.health == .critical)
        #expect(group.healthText == "紧急")
        #expect(group.warningCount == 1)
        #expect(group.criticalCount == 1)
    }

    @Test
    func unsetAccountsDoNotMaskHealthyProviderHealth() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    balanceRow(provider: .deepSeek, amount: 50, warning: 10),
                    balanceRow(provider: .deepSeek, amount: 50),
                ]
            ).first
        )

        #expect(group.health == .normal)
        #expect(group.healthText == "正常")
    }

    @Test
    func aProviderWithOnlyUnsetAccountsReportsUnsetHealth() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [balanceRow(provider: .deepSeek, amount: 50)]
            ).first
        )

        #expect(group.health == .unset)
        #expect(group.healthText == "未设置")
    }

    @Test
    func errorAndStaleAreCountedSeparatelyFromProviderHealth() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    // A Stale critical Account still contributes its last known
                    // Health, matching the row and menu bar.
                    balanceRow(
                        provider: .deepSeek,
                        amount: 1,
                        warning: 10,
                        critical: 5,
                        status: .stale
                    ),
                    balanceRow(
                        provider: .deepSeek,
                        amount: 0,
                        status: .error,
                        error: .network
                    ),
                    balanceRow(provider: .deepSeek, amount: 50, warning: 10),
                ]
            ).first
        )

        #expect(group.health == .critical)
        #expect(group.criticalCount == 1)
        #expect(group.warningCount == 0)
        #expect(group.errorCount == 1)
        #expect(group.staleCount == 1)
    }

    @Test
    func eachKindSectionReportsItsOwnHealthAndCounts() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    balanceRow(provider: .moonshot, amount: 8, warning: 10),
                    quotaRow(label: "紧急", remaining: 5, warning: 20, critical: 10),
                    quotaRow(label: "正常", remaining: 80, warning: 20, critical: 10),
                ]
            ).first
        )
        let balanceSection = try #require(group.sections.first { $0.kind == .balance })
        let quotaSection = try #require(group.sections.first { $0.kind == .subscription })

        #expect(balanceSection.health == .warning)
        #expect(balanceSection.warningCount == 1)
        #expect(balanceSection.criticalCount == 0)
        #expect(quotaSection.health == .critical)
        #expect(quotaSection.warningCount == 0)
        #expect(quotaSection.criticalCount == 1)
        #expect(group.health == .critical)
        #expect(group.warningCount == 1)
        #expect(group.criticalCount == 1)
    }

    @Test
    func sectionErrorAndStaleCountsStaySeparateFromHealthCounts() throws {
        let group = try #require(
            ProviderGroupPresentation.groups(
                from: [
                    balanceRow(provider: .deepSeek, amount: 8, warning: 10),
                    balanceRow(
                        provider: .deepSeek,
                        amount: 4,
                        warning: 10,
                        critical: 5
                    ),
                    balanceRow(provider: .deepSeek, amount: 0, status: .error, error: .network),
                    balanceRow(provider: .deepSeek, amount: 50, warning: 10, status: .stale),
                ]
            ).first
        )
        let section = try #require(group.sections.first)

        #expect(section.accountCount == 4)
        #expect(section.warningCount == 1)
        #expect(section.criticalCount == 1)
        #expect(section.errorCount == 1)
        #expect(section.staleCount == 1)
        #expect(group.errorCount == 1)
        #expect(group.staleCount == 1)
    }

    // MARK: Collapse state

    @Test
    func collapseStateMarksOnlyTheCollapsedProvider() throws {
        var collapse = ProviderCollapseState()
        collapse.toggle(.moonshot)
        let groups = ProviderGroupPresentation.groups(
            from: [
                balanceRow(provider: .deepSeek),
                balanceRow(provider: .moonshot),
            ],
            collapseState: collapse
        )

        let deepSeek = try #require(groups.first { $0.provider == .deepSeek })
        let moonshot = try #require(groups.first { $0.provider == .moonshot })
        #expect(!deepSeek.isCollapsed)
        #expect(moonshot.isCollapsed)
    }

    @Test
    func collapsingAProviderKeepsItsPerKindSummariesAvailable() throws {
        var collapse = ProviderCollapseState()
        collapse.toggle(.moonshot)
        let rows = [
            balanceRow(provider: .moonshot, currency: .cny, amount: 30),
            balanceRow(provider: .moonshot, currency: .usd, amount: 5),
            quotaRow(label: "Kimi Code", remaining: 15, warning: 20, critical: 10),
        ]

        let expanded = try #require(
            ProviderGroupPresentation.groups(from: rows).first
        )
        let collapsed = try #require(
            ProviderGroupPresentation.groups(from: rows, collapseState: collapse).first
        )

        #expect(collapsed.isCollapsed)
        #expect(collapsed.sections == expanded.sections)
        let balanceSection = try #require(collapsed.sections.first { $0.kind == .balance })
        let quotaSection = try #require(collapsed.sections.first { $0.kind == .subscription })
        #expect(balanceSection.balanceTotals.map(\.amountText) == ["¥30.00", "$5.00"])
        #expect(quotaSection.quotaWorstRemainingText == "15%")
        #expect(quotaSection.health == .warning)
    }
}

// MARK: - Fixtures

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

private func balanceRow(
    id: UUID = UUID(),
    provider: Provider,
    label: String = "账户",
    currency: Currency = .cny,
    amount: Decimal = 50,
    warning: Decimal? = nil,
    critical: Decimal? = nil,
    status: SnapshotStatus? = .fresh,
    error: BalanceProviderError? = nil
) -> BalanceRow {
    let account = Account(
        id: id,
        provider: provider,
        currency: currency,
        label: label,
        warningThreshold: warning,
        criticalThreshold: critical
    )
    let snapshot = status.map { _ in
        BalanceSnapshot(
            accountID: id,
            balance: Balance(amount: amount, currency: currency),
            fetchedAt: fixedNow,
            isAvailable: status != .unavailable
        )
    }
    return BalanceRow(
        account: account,
        snapshot: snapshot.map(AccountSnapshot.balance),
        status: status,
        error: error
    )
}

private func quotaRow(
    id: UUID = UUID(),
    label: String = "Kimi Code",
    limit: Decimal = 100,
    remaining: Decimal,
    warning: Decimal? = nil,
    critical: Decimal? = nil,
    status: SnapshotStatus? = .fresh,
    error: BalanceProviderError? = nil
) -> BalanceRow {
    let account = Account(
        id: id,
        provider: .moonshot,
        kind: .subscription,
        label: label,
        warningThreshold: warning,
        criticalThreshold: critical
    )
    let snapshot = status.map { _ in
        QuotaSnapshot(
            accountID: id,
            limit: limit,
            remaining: remaining,
            fetchedAt: fixedNow
        )
    }
    return BalanceRow(
        account: account,
        snapshot: snapshot.map(AccountSnapshot.quota),
        status: status,
        error: error
    )
}
