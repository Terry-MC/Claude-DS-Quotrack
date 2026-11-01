/// A balance-capable AI service Provider. v1 supports only Providers with a
/// documented individual Balance API; see ADR-0001.
enum Provider: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case deepSeek
    case moonshot
    case siliconFlow
    case openRouter

    var displayName: String {
        switch self {
        case .deepSeek: "DeepSeek"
        case .moonshot: "Moonshot (Kimi)"
        case .siliconFlow: "SiliconFlow"
        case .openRouter: "OpenRouter"
        }
    }

    /// Whether the Provider has independently credentialed Regions in v1.
    var supportsRegion: Bool {
        switch self {
        case .moonshot, .siliconFlow: true
        case .deepSeek, .openRouter: false
        }
    }
}
