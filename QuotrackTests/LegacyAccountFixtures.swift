import Foundation

/// Recorded v1 `accounts.json` content from before SiliconFlow was dropped.
/// The Provider case and the legacy `lowBalanceThreshold` key must keep
/// decoding even though the Account can no longer be added or polled.
enum LegacyAccountFixtures {
    static let siliconFlowAccountID = UUID(
        uuidString: "9E8B7A6C-5D4E-4321-8ABC-DEF012345678"
    )!
    static let deepSeekAccountID = UUID(
        uuidString: "1A2B3C4D-5E6F-4A8B-9C0D-1E2F3A4B5C6D"
    )!

    static let siliconFlowBalance = Balance(
        amount: Decimal(string: "15.00")!,
        currency: .cny
    )

    static let accountsJSON = """
    [{"id":"\(siliconFlowAccountID.uuidString)","provider":"siliconFlow","region":"domestic",\
    "label":"SiliconFlow 国内","lowBalanceThreshold":10.5}]
    """

    /// A recorded v1 `accounts.json` with an ordinary Balance Account and a
    /// SiliconFlow Account. Both carry the old `lowBalanceThreshold` key.
    static let mixedAccountsJSON = """
    [{"id":"\(deepSeekAccountID.uuidString)","provider":"deepSeek",\
    "label":"个人账户","lowBalanceThreshold":10.5},\
    {"id":"\(siliconFlowAccountID.uuidString)","provider":"siliconFlow","region":"domestic",\
    "label":"SiliconFlow 国内","lowBalanceThreshold":10.5}]
    """

    static let legacySnapshotFetchedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A recorded v1 `snapshots.json`. v1 records had no `kind` key, so both
    /// must decode as Balance Snapshots.
    static let snapshotsJSON = """
    [{"accountID":"\(deepSeekAccountID.uuidString)",\
    "balance":{"amount":12.25,"currency":{"code":"CNY","symbol":"¥"}},\
    "fetchedAt":800000000,"isAvailable":true},\
    {"accountID":"\(siliconFlowAccountID.uuidString)",\
    "balance":{"amount":15,"currency":{"code":"CNY","symbol":"¥"}},\
    "fetchedAt":800000000,"isAvailable":true}]
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
