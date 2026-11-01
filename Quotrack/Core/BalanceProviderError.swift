import Foundation

/// The typed failure categories every Provider adapter maps its errors into.
/// Keeping them Provider-neutral lets the monitor and panel treat failures
/// uniformly. A failure may also carry the delay a Provider asked for, such as
/// `Retry-After` on HTTP 429; the category remains the error's identity.
struct BalanceProviderError: Error, Hashable, Sendable, CaseIterable {
    enum Category: String, Sendable, Equatable, Hashable, CaseIterable {
        case authentication
        case permission
        case network
        case rateLimit
        case malformedResponse
        case unknown
    }

    let category: Category

    /// A Provider-requested delay before the next attempt, when one was given.
    let retryAfter: TimeInterval?

    init(_ category: Category, retryAfter: TimeInterval? = nil) {
        self.category = category
        self.retryAfter = retryAfter
    }

    static let authentication = Self(.authentication)
    static let permission = Self(.permission)
    static let network = Self(.network)
    static let rateLimit = Self(.rateLimit)
    static let malformedResponse = Self(.malformedResponse)
    static let unknown = Self(.unknown)

    /// A rate-limit failure. The delay comes from `Retry-After` when the
    /// Provider supplied one; otherwise the monitor uses its normal backoff.
    static func rateLimit(retryAfter: TimeInterval?) -> Self {
        Self(.rateLimit, retryAfter: retryAfter)
    }

    static var allCases: [BalanceProviderError] {
        Category.allCases.map { Self($0) }
    }

    /// Two failures are the same category regardless of the retry delay, so
    /// retry metadata never changes how an error is reported or grouped.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.category == rhs.category
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(category)
    }

    /// The user-facing explanation for this failure. Provider-aware because
    /// OpenRouter's permission failure needs the management-key message.
    func userMessage(for provider: Provider) -> String {
        switch category {
        case .authentication:
            UIStrings.authenticationError
        case .permission:
            provider == .openRouter
                ? UIStrings.openRouterManagementKeyError
                : UIStrings.permissionError
        case .network:
            UIStrings.networkError
        case .rateLimit:
            UIStrings.rateLimitError
        case .malformedResponse:
            UIStrings.malformedResponseError
        case .unknown:
            UIStrings.unknownError
        }
    }

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
