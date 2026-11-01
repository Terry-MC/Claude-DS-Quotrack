import Foundation

/// The typed failure categories every Provider adapter maps its errors into.
/// Keeping them Provider-neutral lets the monitor and panel treat failures
/// uniformly.
enum BalanceProviderError: Error, Equatable, Sendable, CaseIterable {
    case authentication
    case permission
    case network
    case rateLimit
    case malformedResponse
    case unknown

    /// Normalizes any thrown error into the shared categories. Adapters throw
    /// typed errors directly; transport and decoding failures that escape an
    /// adapter are still classified here so the monitor never stores an
    /// arbitrary error type.
    static func classify(_ error: Error) -> BalanceProviderError {
        if let typed = error as? BalanceProviderError {
            return typed
        }
        if error is URLError {
            return .network
        }
        if error is DecodingError {
            return .malformedResponse
        }
        return .unknown
    }
}
