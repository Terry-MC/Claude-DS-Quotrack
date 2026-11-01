import Foundation

/// App-wide preferences that are not part of an Account. The Polling Interval
/// is stored in minutes because that is the unit the Settings UI edits; the
/// monitor consumes seconds.
struct AppSettings: Codable, Equatable, Sendable {
    static let defaultPollingIntervalMinutes = 5
    static let pollingIntervalRange = 1...60

    /// The time between automatic balance queries, in minutes. Values outside
    /// one through sixty are clamped rather than rejected, so a stale or
    /// hand-edited file can never configure a zero or excessive interval.
    let pollingIntervalMinutes: Int

    init(pollingIntervalMinutes: Int = AppSettings.defaultPollingIntervalMinutes) {
        self.pollingIntervalMinutes = min(
            max(pollingIntervalMinutes, Self.pollingIntervalRange.lowerBound),
            Self.pollingIntervalRange.upperBound
        )
    }

    var pollingInterval: TimeInterval {
        TimeInterval(pollingIntervalMinutes * 60)
    }

    private enum CodingKeys: String, CodingKey {
        case pollingIntervalMinutes
    }

    /// Decoding goes through the same clamp as construction, so a hand-edited
    /// or corrupted file cannot introduce an out-of-range interval.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let minutes = try container.decodeIfPresent(Int.self, forKey: .pollingIntervalMinutes)
            ?? Self.defaultPollingIntervalMinutes
        self.init(pollingIntervalMinutes: minutes)
    }
}
