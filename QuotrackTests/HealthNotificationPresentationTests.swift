import Foundation
import Testing

/// One poll batch becomes at most one notification, with every transition
/// listed in the body and the first affected Account carried for click focus.
struct HealthNotificationPresentationTests {
    @Test
    func oneTransitionBecomesOneNotification() throws {
        let account = HealthTestSupport.balanceAccount(label: "个人账户")
        let transition = HealthTransition(
            accountID: account.id,
            provider: account.provider,
            label: account.label,
            kind: account.kind,
            from: .normal,
            to: .warning
        )

        let content = try #require(
            HealthNotificationPresentation.content(
                for: HealthNotificationBatch(transitions: [transition])
            )
        )

        #expect(content.title == UIStrings.healthNotificationTitle)
        #expect(content.body.contains("DeepSeek"))
        #expect(content.body.contains("个人账户"))
        #expect(content.body.contains("正常"))
        #expect(content.body.contains("预警"))
        #expect(content.affectedAccountIDs == [account.id])
        #expect(content.severity == .warning)
    }

    @Test
    func multipleTransitionsAreAggregatedIntoOneNotification() throws {
        let first = HealthTestSupport.balanceAccount(label: "第一个")
        let second = HealthTestSupport.quotaAccount(label: "第二个")
        let transitions = [
            HealthTransition(
                accountID: first.id,
                provider: first.provider,
                label: first.label,
                kind: first.kind,
                from: .normal,
                to: .warning
            ),
            HealthTransition(
                accountID: second.id,
                provider: second.provider,
                label: second.label,
                kind: second.kind,
                from: .warning,
                to: .critical
            ),
        ]

        let content = try #require(
            HealthNotificationPresentation.content(
                for: HealthNotificationBatch(transitions: transitions)
            )
        )

        #expect(content.affectedAccountIDs == [first.id, second.id])
        #expect(content.body.contains("2 个账户"))
        #expect(content.body.contains("第一个"))
        #expect(content.body.contains("第二个"))
        #expect(content.severity == .critical)
    }

    @Test
    func aRecoveryOnlyBatchUsesTheRecoveryTitle() throws {
        let account = HealthTestSupport.balanceAccount()
        let transition = HealthTransition(
            accountID: account.id,
            provider: account.provider,
            label: account.label,
            kind: account.kind,
            from: .critical,
            to: .normal
        )

        let content = try #require(
            HealthNotificationPresentation.content(
                for: HealthNotificationBatch(transitions: [transition])
            )
        )

        #expect(content.title == UIStrings.healthRecoveryNotificationTitle)
        #expect(content.severity == .normal)
    }

    @Test
    func aMixedBatchUsesTheAlertTitle() throws {
        let first = HealthTestSupport.balanceAccount(label: "恢复")
        let second = HealthTestSupport.quotaAccount(label: "预警")
        let transitions = [
            HealthTransition(
                accountID: first.id,
                provider: first.provider,
                label: first.label,
                kind: first.kind,
                from: .warning,
                to: .normal
            ),
            HealthTransition(
                accountID: second.id,
                provider: second.provider,
                label: second.label,
                kind: second.kind,
                from: .normal,
                to: .warning
            ),
        ]

        let content = try #require(
            HealthNotificationPresentation.content(
                for: HealthNotificationBatch(transitions: transitions)
            )
        )

        #expect(content.title == UIStrings.healthNotificationTitle)
        #expect(content.severity == .warning)
    }

    @Test
    func anEmptyBatchProducesNoNotification() {
        #expect(
            HealthNotificationPresentation.content(
                for: HealthNotificationBatch(transitions: [])
            ) == nil
        )
    }

    @Test
    func theFirstAffectedAccountIsTheFirstTransitionInRowOrder() {
        let first = UUID()
        let second = UUID()
        let transitions = [first, second].map { id in
            HealthTransition(
                accountID: id,
                provider: .deepSeek,
                label: "账户",
                kind: .balance,
                from: .normal,
                to: .warning
            )
        }

        let batch = HealthNotificationBatch(transitions: transitions)

        #expect(batch.firstAffectedAccountID == first)
    }
}
