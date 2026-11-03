import Foundation
import Testing

struct ConnectionTesterTests {
    @Test
    func mockConnectionTestingSucceedsForEverySupportedProvider() async throws {
        let tester = MockConnectionTester(now: { Date(timeIntervalSince1970: 1_800_000_000) })

        for provider in Provider.allCases {
            let snapshot = try await tester.testConnection(
                AccountDraft(
                    provider: provider,
                    region: provider.supportsRegion ? .international : nil,
                    label: "账户",
                    credential: "sk-test"
                )
            )
            #expect(snapshot.balanceSnapshot?.balance.currency == .cny)
            #expect(snapshot.isAvailable)
            #expect(snapshot.fetchedAt == Date(timeIntervalSince1970: 1_800_000_000))
        }
    }

    @Test
    func theLiveTesterRoutesByProviderAndKind() async throws {
        let balanceSnapshot = BalanceSnapshot(
            accountID: UUID(),
            balance: Balance(amount: 10, currency: .cny),
            fetchedAt: Date(),
            isAvailable: true
        )
        let quotaSnapshot = QuotaSnapshot(
            accountID: UUID(),
            limit: 100,
            remaining: 60,
            fetchedAt: Date()
        )
        let tester = ProviderRegistryConnectionTester(adapters: [
            ProviderAdapterKey(provider: .moonshot, kind: .balance):
                StubCredentialAdapter(snapshot: .balance(balanceSnapshot)),
            ProviderAdapterKey(provider: .moonshot, kind: .subscription):
                StubCredentialAdapter(snapshot: .quota(quotaSnapshot)),
        ])

        let balanceDraft = AccountDraft(
            provider: .moonshot,
            label: "Kimi 充值",
            credential: "sk-moonshot",
            kind: .balance
        )
        let quotaDraft = AccountDraft(
            provider: .moonshot,
            label: "Kimi Code",
            credential: "sk-kimi",
            kind: .subscription
        )

        #expect(try await tester.testConnection(balanceDraft) == .balance(balanceSnapshot))
        #expect(try await tester.testConnection(quotaDraft) == .quota(quotaSnapshot))
    }

    @Test
    func anUnregisteredLiveAdapterFailsWithAnUnsupportedKindError() async {
        let tester = ProviderRegistryConnectionTester(adapters: [:])

        await #expect(throws: BalanceProviderError.unsupportedAccountKind) {
            try await tester.testConnection(
                AccountDraft(
                    provider: .deepSeek,
                    label: "账户",
                    credential: "sk-test"
                )
            )
        }
    }
}

private struct StubCredentialAdapter: CredentialAccountAdapter {
    let snapshot: AccountSnapshot

    func fetchSnapshot(
        region: Region?,
        credential: String,
        kind: AccountKind
    ) async throws -> AccountSnapshot {
        snapshot
    }
}
