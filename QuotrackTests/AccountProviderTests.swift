import Foundation
import Testing

struct AccountProviderTests {
    @Test
    func theRegistryRoutesBalanceAndQuotaAccountsToDifferentAdapters() async throws {
        let balanceAccount = Account(
            id: UUID(),
            provider: .moonshot,
            label: "Kimi 充值"
        )
        let quotaAccount = Account(
            id: UUID(),
            provider: .moonshot,
            kind: .subscription,
            label: "Kimi Code"
        )
        let balanceSnapshot = BalanceSnapshot(
            accountID: balanceAccount.id,
            balance: Balance(amount: 10, currency: .cny),
            fetchedAt: now,
            isAvailable: true
        )
        let quotaSnapshot = QuotaSnapshot(
            accountID: quotaAccount.id,
            limit: 100,
            remaining: 60,
            fetchedAt: now
        )
        let registry = ProviderRegistry(adapters: [
            ProviderAdapterKey(provider: .moonshot, kind: .balance):
                StubAccountProvider(snapshot: .balance(balanceSnapshot)),
            ProviderAdapterKey(provider: .moonshot, kind: .subscription):
                StubAccountProvider(snapshot: .quota(quotaSnapshot)),
        ])

        let balanceResult = try await registry.fetchSnapshot(for: balanceAccount)
        let quotaResult = try await registry.fetchSnapshot(for: quotaAccount)

        #expect(balanceResult == .balance(balanceSnapshot))
        #expect(quotaResult == .quota(quotaSnapshot))
    }

    @Test
    func anUnsupportedProviderAndKindCombinationFailsWithATypedError() async {
        let registry = ProviderRegistry(adapters: [:])
        let account = Account(
            id: UUID(),
            provider: .moonshot,
            kind: .subscription,
            label: "Kimi Code"
        )

        await #expect(throws: BalanceProviderError.unsupportedAccountKind) {
            try await registry.fetchSnapshot(for: account)
        }
    }
}

private struct StubAccountProvider: AccountProvider {
    let snapshot: AccountSnapshot

    func fetchSnapshot(for account: Account) async throws -> AccountSnapshot {
        snapshot
    }
}

private let now = Date(timeIntervalSince1970: 1_800_000_000)
