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
}
