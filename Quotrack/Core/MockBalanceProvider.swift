import Foundation

/// A BalanceProvider for the mock slice. It returns one fixed Balance
/// Snapshot for any Account, so the UI and monitor run without credentials,
/// network, or Keychain access.
/// A deterministic Quota source for mock-mode subscription Accounts and
/// previews. The weekly quota is primary; the 5-hour window is secondary.
struct MockQuotaProvider: AccountProvider {
    private let snapshots: [Account.ID: QuotaSnapshot]

    init(now: Date) {
        self.init(fixtures: MockFixtures.quotaFixtures(now: now))
    }

    init(fixtures: [MockQuotaFixture]) {
        self.snapshots = Dictionary(
            uniqueKeysWithValues: fixtures.map { ($0.account.id, $0.snapshot) }
        )
    }

    func fetchSnapshot(for account: Account) async throws -> AccountSnapshot {
        guard let snapshot = snapshots[account.id] else {
            throw BalanceProviderError.unknown
        }
        return .quota(snapshot)
    }
}

struct MockBalanceProvider: BalanceProvider {
    static let amount = Decimal(string: "42.50")!
    static let currency = Currency.cny

    private let fixedFetchedAt: Date?
    private let outcomes: [Account.ID: MockOutcome]

    init(fetchedAt: Date = Date()) {
        self.fixedFetchedAt = fetchedAt
        self.outcomes = [:]
    }

    init(fixtures: [MockFixture]) {
        self.fixedFetchedAt = nil
        self.outcomes = Dictionary(
            uniqueKeysWithValues: fixtures.map { ($0.account.id, $0.outcome) }
        )
    }

    func fetchBalance(for account: Account) async throws -> BalanceSnapshot {
        if let outcome = outcomes[account.id] {
            switch outcome {
            case let .balance(balance, breakdown, fetchedAt):
                return BalanceSnapshot(
                    accountID: account.id,
                    balance: balance,
                    fetchedAt: fetchedAt,
                    isAvailable: true,
                    breakdown: breakdown
                )
            case let .failure(error):
                throw error
            }
        }

        guard let fixedFetchedAt else {
            throw BalanceProviderError.unknown
        }
        return BalanceSnapshot(
            accountID: account.id,
            balance: Balance(amount: Self.amount, currency: Self.currency),
            fetchedAt: fixedFetchedAt,
            isAvailable: true
        )
    }
}
