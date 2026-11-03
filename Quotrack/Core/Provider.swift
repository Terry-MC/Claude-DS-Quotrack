/// A balance-capable AI service Provider. v2 supports only Providers with a
/// currently available personal query path; see ADR-0002.
enum Provider: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case deepSeek
    case moonshot
    /// Legacy-only. Kept so v1 `accounts.json` files still decode; v2 never
    /// offers this Provider and never polls its Accounts.
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

    /// Whether v2 can query the Provider with a direct personal credential.
    /// SiliconFlow's balance endpoint stopped serving in 2026-08.
    var isSupported: Bool {
        switch self {
        case .deepSeek, .moonshot, .openRouter: true
        case .siliconFlow: false
        }
    }

    /// A Provider whose persisted Accounts remain decodable but are never
    /// offered in the add-Account or onboarding pickers.
    var isLegacyUnsupported: Bool {
        !isSupported
    }

    /// The Provider choices the add-Account and onboarding pickers show.
    static var addableCases: [Provider] {
        allCases.filter { $0.isSupported }
    }

    /// Whether the Provider has independently credentialed Regions. It stays
    /// true for SiliconFlow so legacy Accounts keep their Region on disk.
    var supportsRegion: Bool {
        switch self {
        case .moonshot, .siliconFlow: true
        case .deepSeek, .openRouter: false
        }
    }
}
