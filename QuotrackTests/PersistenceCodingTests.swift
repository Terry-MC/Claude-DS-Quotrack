import Foundation
import Testing

struct PersistenceCodingTests {
    @Test
    func balanceSnapshotRoundTripsThroughJSON() throws {
        let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = BalanceSnapshot(
            accountID: accountID,
            balance: Balance(amount: Decimal(string: "42.50")!, currency: .cny),
            fetchedAt: fetchedAt,
            isAvailable: true
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BalanceSnapshot.self, from: data)

        #expect(decoded == snapshot)
        #expect(decoded.balance.amount == Decimal(string: "42.50")!)
        #expect(decoded.balance.currency == Currency(code: "CNY", symbol: "¥"))
        #expect(decoded.fetchedAt == fetchedAt)
        #expect(decoded.isAvailable)
        #expect(decoded.breakdown == nil)
    }

    @Test
    func legacyAccountJSONMigratesToBalanceKindAndWarningThreshold() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuotrackAccountMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID()
        let legacyJSON = """
        [{"id":"\(accountID.uuidString)","provider":"deepSeek","label":"个人账户","lowBalanceThreshold":10.5}]
        """
        try Data(legacyJSON.utf8).write(
            to: directory.appendingPathComponent("accounts.json")
        )

        let accounts = FileSnapshotStore(directoryURL: directory).loadAccounts()

        let account = try #require(accounts.first)
        #expect(account.id == accountID)
        #expect(account.kind == .balance)
        #expect(account.warningThreshold == Decimal(string: "10.5"))
        #expect(account.criticalThreshold == nil)
        #expect(account.warningThreshold == Decimal(string: "10.5"))
    }

    @Test
    func accountKindAndThresholdsRoundTripThroughJSON() throws {
        let account = Account(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            provider: .moonshot,
            region: .domestic,
            kind: .subscription,
            currency: .cny,
            label: "Kimi Code",
            warningThreshold: 20,
            criticalThreshold: 10
        )

        let data = try JSONEncoder().encode([account])
        let decoded = try JSONDecoder().decode([Account].self, from: data)

        #expect(decoded == [account])
        #expect(decoded.first?.kind == .subscription)
        #expect(decoded.first?.currency == .cny)
        #expect(decoded.first?.warningThreshold == 20)
        #expect(decoded.first?.criticalThreshold == 10)
    }

    @Test
    func invalidPersistedThresholdsDecodeAsUnset() throws {
        let subscription = Account(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            provider: .moonshot,
            kind: .subscription,
            label: "Kimi Code",
            warningThreshold: 150
        )
        let balance = Account(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            provider: .deepSeek,
            label: "个人账户",
            warningThreshold: 5,
            criticalThreshold: 10
        )

        let data = try JSONEncoder().encode([subscription, balance])
        let decoded = try JSONDecoder().decode([Account].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].warningThreshold == nil)
        #expect(decoded[0].criticalThreshold == nil)
        #expect(decoded[1].warningThreshold == nil)
        #expect(decoded[1].criticalThreshold == nil)
    }

    @Test
    func quotaSnapshotRoundTripsAndDerivesUsage() throws {
        let resetAt = Date(timeIntervalSince1970: 1_800_000_300)
        let snapshot = QuotaSnapshot(
            accountID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            limit: 100,
            remaining: 60,
            resetAt: resetAt,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            packages: [
                QuotaPackage(
                    name: "Kimi Code",
                    limit: 100,
                    remaining: 60,
                    expiresAt: resetAt
                ),
            ],
            windows: [
                QuotaWindow(
                    name: "5 小时窗口",
                    limit: 100,
                    remaining: 85,
                    resetAt: resetAt
                ),
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(QuotaSnapshot.self, from: data)

        #expect(decoded == snapshot)
        #expect(decoded.used == 40)
        #expect(decoded.usedRatio == Decimal(string: "0.4"))
        #expect(decoded.windows?.first?.name == "5 小时窗口")
    }

    @Test
    func balanceSnapshotBreakdownRoundTripsThroughJSON() throws {
        let snapshot = BalanceSnapshot(
            accountID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            balance: Balance(amount: Decimal(string: "128.40")!, currency: .cny),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isAvailable: true,
            breakdown: [
                BalanceBreakdownItem(kind: .granted, amount: Decimal(string: "28.40")!),
                BalanceBreakdownItem(kind: .toppedUp, amount: Decimal(string: "100.00")!),
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BalanceSnapshot.self, from: data)

        #expect(decoded == snapshot)
        #expect(decoded.breakdown?.map(\.kind) == [.granted, .toppedUp])
    }
}
