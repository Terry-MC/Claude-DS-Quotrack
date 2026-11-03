import Foundation
import Testing

struct ThresholdGaugePresentationTests {
    @Test
    func bothThresholdsProduceCriticalWarningAndNormalZones() {
        let account = makeAccount(warning: 10, critical: 5)

        let segments = ThresholdGaugePresentation.segments(for: account, health: .warning)

        #expect(segments.map(\.role) == [.critical, .warning, .normal])
        #expect(segments.map(\.isActive) == [false, true, false])
    }

    @Test
    func warningOnlyOmitsTheCriticalZone() {
        let account = makeAccount(warning: 10)

        let segments = ThresholdGaugePresentation.segments(for: account, health: .warning)

        #expect(segments.map(\.role) == [.warning, .normal])
        #expect(segments.map(\.isActive) == [true, false])
    }

    @Test
    func criticalOnlyOmitsTheWarningZone() {
        let account = makeAccount(critical: 5)

        let segments = ThresholdGaugePresentation.segments(for: account, health: .critical)

        #expect(segments.map(\.role) == [.critical, .normal])
        #expect(segments.map(\.isActive) == [true, false])
    }

    @Test
    func noThresholdsProduceNoGauge() {
        let account = makeAccount()

        #expect(ThresholdGaugePresentation.segments(for: account, health: .unset).isEmpty)
    }

    @Test
    func unsetHealthLeavesEveryZoneInactive() {
        let account = makeAccount(warning: 10, critical: 5)

        let segments = ThresholdGaugePresentation.segments(for: account, health: .unset)

        #expect(segments.map(\.isActive) == [false, false, false])
    }

    private func makeAccount(
        warning: Decimal? = nil,
        critical: Decimal? = nil
    ) -> Account {
        Account(
            id: UUID(),
            provider: .deepSeek,
            label: "账户",
            warningThreshold: warning,
            criticalThreshold: critical
        )
    }
}
