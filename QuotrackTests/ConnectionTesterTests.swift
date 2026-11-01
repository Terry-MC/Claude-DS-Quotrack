import Foundation
import Testing

struct ConnectionTesterTests {
    @Test
    func mockConnectionTestingSucceedsForEverySupportedProvider() async throws {
        let tester = MockConnectionTester(now: { Date(timeIntervalSince1970: 1_800_000_000) })

        for provider in Provider.allCases {
            let snapshot = try await tester.testConnection(
                provider: provider,
                region: provider.supportsRegion ? .international : nil,
                credential: "sk-test"
            )
            #expect(snapshot.balance.currency == .cny)
            #expect(snapshot.isAvailable)
            #expect(snapshot.fetchedAt == Date(timeIntervalSince1970: 1_800_000_000))
        }
    }

    @Test
    func anUnregisteredLiveAdapterFailsWithAnUnknownError() async {
        let tester = ProviderRegistryConnectionTester(adapters: [:])

        await #expect(throws: BalanceProviderError.unknown) {
            try await tester.testConnection(
                provider: .deepSeek,
                region: nil,
                credential: "sk-test"
            )
        }
    }
}
