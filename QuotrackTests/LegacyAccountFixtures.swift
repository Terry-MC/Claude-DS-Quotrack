import Foundation

/// Recorded v1 `accounts.json` content from before SiliconFlow was dropped.
/// The Provider case and the legacy `lowBalanceThreshold` key must keep
/// decoding even though the Account can no longer be added or polled.
enum LegacyAccountFixtures {
    static let siliconFlowAccountID = UUID(
        uuidString: "9E8B7A6C-5D4E-4321-8ABC-DEF012345678"
    )!

    static let siliconFlowBalance = Balance(
        amount: Decimal(string: "15.00")!,
        currency: .cny
    )

    static let accountsJSON = """
    [{"id":"\(siliconFlowAccountID.uuidString)","provider":"siliconFlow","region":"domestic",\
    "label":"SiliconFlow 国内","lowBalanceThreshold":10.5}]
    """

    static func snapshot(fetchedAt: Date) -> BalanceSnapshot {
        BalanceSnapshot(
            accountID: siliconFlowAccountID,
            balance: siliconFlowBalance,
            fetchedAt: fetchedAt,
            isAvailable: true
        )
    }
}
