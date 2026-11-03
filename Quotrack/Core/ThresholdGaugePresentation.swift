import Foundation

struct ThresholdGaugeSegment: Equatable, Sendable {
    enum Role: Equatable, Sendable {
        case critical
        case warning
        case normal
    }

    let role: Role
    let isActive: Bool
}

/// The zones a Balance threshold gauge shows. The gauge is a status strip, not
/// a linear money scale: it shows which zones exist and which one is active.
enum ThresholdGaugePresentation {
    static func segments(
        for account: Account,
        health: AccountHealth
    ) -> [ThresholdGaugeSegment] {
        let thresholds = account.thresholds
        guard thresholds.warning != nil || thresholds.critical != nil else {
            return []
        }

        var segments: [ThresholdGaugeSegment] = []
        if thresholds.critical != nil {
            segments.append(
                ThresholdGaugeSegment(
                    role: .critical,
                    isActive: health == .critical
                )
            )
        }
        if thresholds.warning != nil {
            segments.append(
                ThresholdGaugeSegment(
                    role: .warning,
                    isActive: health == .warning
                )
            )
        }
        segments.append(
            ThresholdGaugeSegment(
                role: .normal,
                isActive: health == .normal
            )
        )
        return segments
    }
}
