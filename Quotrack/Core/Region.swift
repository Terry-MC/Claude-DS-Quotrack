import Foundation

/// An independently credentialed deployment area of a Provider. A credential
/// is valid only in its Region. v1 exposes Regions for Moonshot and
/// SiliconFlow; other Providers ignore the value.
enum Region: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case domestic
    case international

    var displayName: String {
        switch self {
        case .domestic: "国内"
        case .international: "国际"
        }
    }
}
