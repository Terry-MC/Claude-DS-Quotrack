import Foundation
import Testing

struct KimiCodeAdapterTests {
    @Test
    func fetchesTheDomesticWeeklyQuotaAndFiveHourWindow() async throws {
        let account = Account(
            id: UUID(),
            provider: .moonshot,
            region: .domestic,
            kind: .subscription,
            label: "Kimi Code"
        )
        let transport = StubHTTPTransport(
            response: .json(body: KimiCodeFixtures.domesticSuccess)
        )
        let adapter = KimiCodeAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [account.id: "sk-kimi-domestic"]
            ),
            now: { now }
        )

        let snapshot = try await adapter.fetchSnapshot(for: account)
        let quota = try #require(snapshot.quotaSnapshot)

        #expect(quota.limit == 100)
        #expect(quota.remaining == 74)
        #expect(quota.resetAt == Self.date("2026-02-11T17:32:50.757941Z"))
        #expect(quota.windows?.count == 1)
        #expect(quota.windows?.first?.name == "5 小时窗口")
        #expect(quota.windows?.first?.remaining == 85)

        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.url == KimiCodeAdapter.domesticEndpoint)
        #expect(
            request.headers["Authorization"]
                == "Bearer sk-kimi-domestic"
        )
    }

    @Test
    func fetchesTheInternationalQuotaFromTheInternationalEndpoint() async throws {
        let account = Account(
            id: UUID(),
            provider: .moonshot,
            region: .international,
            kind: .subscription,
            label: "Kimi Code"
        )
        let transport = StubHTTPTransport(
            response: .json(body: KimiCodeFixtures.internationalEnvelope)
        )
        let adapter = KimiCodeAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [account.id: "sk-kimi-international"]
            ),
            now: { now }
        )

        let snapshot = try await adapter.fetchSnapshot(for: account)
        let quota = try #require(snapshot.quotaSnapshot)

        #expect(quota.limit == 200)
        #expect(quota.remaining == 40)
        #expect(transport.requests.first?.url == KimiCodeAdapter.internationalEndpoint)
    }

    @Test
    func decodesTheNewWeeklyRatioPoolWithMonthlyAndFiveHourWindows() async throws {
        let snapshot = try await fetch(KimiCodeFixtures.ratioPools)
        let quota = try #require(snapshot.quotaSnapshot)

        #expect(quota.limit == 100)
        #expect(quota.remaining == Decimal(string: "91.56"))
        #expect(quota.used == Decimal(string: "8.44"))
        #expect(quota.resetAt == Self.date("2026-02-11T17:32:50.757941Z"))

        let windows = try #require(quota.windows)
        #expect(windows.map(\.name) == ["5 小时窗口", "本月用量"])
        #expect(windows[0].remaining == 100)
        #expect(windows[1].remaining == 80)
    }

    @Test
    func fallsBackToTheMonthlyRatioWhenWeeklyIsMissing() async throws {
        let snapshot = try await fetch(KimiCodeFixtures.ratioPoolsWithoutWeekly)
        let quota = try #require(snapshot.quotaSnapshot)

        // 8.44 is treated as an already-percentage used_ratio.
        #expect(quota.remaining == Decimal(string: "91.56"))
        #expect(quota.used == Decimal(string: "8.44"))
        #expect(quota.windows?.map(\.name) == ["5 小时窗口"])
    }

    @Test
    func decodesRatioPoolsInsideTheDataEnvelope() async throws {
        let snapshot = try await fetch(KimiCodeFixtures.ratioPoolsEnvelope)
        let quota = try #require(snapshot.quotaSnapshot)

        #expect(quota.remaining == Decimal(string: "91.56"))
        #expect(quota.windows == nil)
        #expect(quota.resetAt == Self.date("2026-02-11T17:32:50.757941Z"))
    }

    @Test
    func fallsBackToTheFirstLimitWhenWeeklyUsageIsMissing() async throws {
        let snapshot = try await fetch(KimiCodeFixtures.weeklyMissing)
        let quota = try #require(snapshot.quotaSnapshot)

        #expect(quota.limit == 100)
        #expect(quota.remaining == 50)
        #expect(quota.windows == nil)
    }

    @Test
    func missingFiveHourWindowLeavesOnlyTheWeeklyQuota() async throws {
        let snapshot = try await fetch(KimiCodeFixtures.fiveHourMissing)
        let quota = try #require(snapshot.quotaSnapshot)

        #expect(quota.limit == 100)
        #expect(quota.remaining == 74)
        #expect(quota.windows == nil)
    }

    @Test
    func aZeroLimitIsMalformed() async {
        await #expect(throws: BalanceProviderError.malformedResponse) {
            _ = try await fetch(KimiCodeFixtures.zeroLimit)
        }
    }

    @Test
    func anInvalidWeeklyUsageIsMalformedEvenWithAValidFiveHourWindow() async {
        await #expect(throws: BalanceProviderError.malformedResponse) {
            _ = try await fetch(KimiCodeFixtures.invalidWeeklyWithFiveHour)
        }
    }

    @Test
    func aMalformedSecondaryWindowDoesNotDiscardTheWeeklyQuota() async throws {
        let snapshot = try await fetch(
            KimiCodeFixtures.malformedSecondaryWithValidWeekly
        )
        let quota = try #require(snapshot.quotaSnapshot)

        #expect(quota.limit == 100)
        #expect(quota.remaining == 74)
        #expect(quota.windows == nil)
    }

    @Test
    func aFiveHourWindowEncodedInSecondsIsRecognized() async throws {
        let snapshot = try await fetch(KimiCodeFixtures.fiveHourSeconds)
        let quota = try #require(snapshot.quotaSnapshot)

        #expect(quota.windows?.first?.name == "5 小时窗口")
        #expect(quota.windows?.first?.remaining == 85)
    }

    @Test
    func everyValidSecondaryWindowIsKept() async throws {
        let snapshot = try await fetch(KimiCodeFixtures.multipleWindows)
        let quota = try #require(snapshot.quotaSnapshot)

        #expect(quota.windows?.count == 2)
        #expect(quota.windows?.map(\.name) == ["5 小时窗口", "额度窗口 2"])
    }

    @Test
    func anUnexpectedShapeIsMalformed() async {
        await #expect(throws: BalanceProviderError.malformedResponse) {
            _ = try await fetch(KimiCodeFixtures.malformed)
        }
    }

    @Test
    func unauthorizedAndForbiddenMapToTheSharedCategories() async {
        let unauthorized = KimiCodeAdapter(
            transport: StubHTTPTransport(response: .json(status: 401, body: "{}")),
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )
        await #expect(throws: BalanceProviderError.authentication) {
            _ = try await unauthorized.fetchSnapshot(
                region: .domestic,
                credential: "sk-kimi",
                kind: .subscription
            )
        }

        let forbidden = KimiCodeAdapter(
            transport: StubHTTPTransport(response: .json(status: 403, body: "{}")),
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )
        await #expect(throws: BalanceProviderError.permission) {
            _ = try await forbidden.fetchSnapshot(
                region: .domestic,
                credential: "sk-kimi",
                kind: .subscription
            )
        }
    }

    @Test
    func rateLimitsCarryRetryAfterWhenPresent() async {
        let withRetry = KimiCodeAdapter(
            transport: StubHTTPTransport(
                response: .json(
                    status: 429,
                    body: "{}",
                    headers: ["Retry-After": "120"]
                )
            ),
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )
        await #expect(
            throws: BalanceProviderError.rateLimit(retryAfter: 120)
        ) {
            _ = try await withRetry.fetchSnapshot(
                region: .domestic,
                credential: "sk-kimi",
                kind: .subscription
            )
        }

        let withoutRetry = KimiCodeAdapter(
            transport: StubHTTPTransport(
                response: .json(status: 429, body: "{}")
            ),
            credentialStore: InMemoryCredentialStore(),
            now: { now }
        )
        await #expect(throws: BalanceProviderError.rateLimit(retryAfter: nil)) {
            _ = try await withoutRetry.fetchSnapshot(
                region: .domestic,
                credential: "sk-kimi",
                kind: .subscription
            )
        }
    }

    @Test
    func theLiveRegistryAndConnectionTesterRouteSubscriptionAccountsToKimi() async throws {
        let account = Account(
            id: UUID(),
            provider: .moonshot,
            region: .domestic,
            kind: .subscription,
            label: "Kimi Code"
        )
        let credentials = InMemoryCredentialStore(
            credentials: [account.id: "sk-kimi"]
        )
        let transport = StubHTTPTransport(
            response: .json(body: KimiCodeFixtures.domesticSuccess)
        )
        let registry = ProviderRegistry.live(
            credentialStore: credentials,
            transport: transport,
            now: { now }
        )
        let tester = ProviderRegistryConnectionTester.live(
            credentialStore: InMemoryCredentialStore(),
            transport: transport,
            now: { now }
        )

        let registrySnapshot = try await registry.fetchSnapshot(for: account)
        #expect(registrySnapshot.quotaSnapshot?.limit == 100)

        let draft = AccountDraft(
            provider: .moonshot,
            region: .domestic,
            label: "Kimi Code",
            credential: "sk-kimi",
            kind: .subscription
        )
        let testerSnapshot = try await tester.testConnection(draft)
        #expect(testerSnapshot.quotaSnapshot?.remaining == 74)
        #expect(transport.requests.count == 2)
    }

    private func fetch(_ body: String) async throws -> AccountSnapshot {
        let account = Account(
            id: UUID(),
            provider: .moonshot,
            region: .domestic,
            kind: .subscription,
            label: "Kimi Code"
        )
        let transport = StubHTTPTransport(response: .json(body: body))
        let adapter = KimiCodeAdapter(
            transport: transport,
            credentialStore: InMemoryCredentialStore(
                credentials: [account.id: "sk-kimi"]
            ),
            now: { now }
        )
        return try await adapter.fetchSnapshot(for: account)
    }

    private static func date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        return formatter.date(from: string)
    }
}

private let now = Date(timeIntervalSince1970: 1_800_000_000)
