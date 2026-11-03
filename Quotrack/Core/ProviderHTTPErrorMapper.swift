import Foundation

/// The one status-to-error mapping shared by every balance adapter. Providers
/// differ only in what a 401 means: OpenRouter requires a management key, so
/// both 401 and 403 are permission failures there, while the others treat 401
/// as authentication. Retry-After parsing lives here too, so all Providers
/// accept both the seconds and HTTP-date forms.
enum ProviderHTTPErrorMapper {
    static func error(
        for response: HTTPResponse,
        unauthorized: BalanceProviderError = .authentication,
        now: Date
    ) -> BalanceProviderError {
        switch response.statusCode {
        case 401:
            BalanceProviderError(
                unauthorized.category,
                retryAfter: unauthorized.retryAfter,
                statusCode: 401
            )
        case 403:
            BalanceProviderError(.permission, statusCode: 403)
        case 429:
            BalanceProviderError(
                .rateLimit,
                retryAfter: retryAfter(from: response, now: now),
                statusCode: 429
            )
        default:
            BalanceProviderError(
                .unknown,
                statusCode: response.statusCode
            )
        }
    }

    private static func retryAfter(
        from response: HTTPResponse,
        now: Date
    ) -> TimeInterval? {
        guard
            let raw = response.header("Retry-After")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }
        if let seconds = TimeInterval(raw) {
            return seconds >= 0 ? seconds : nil
        }
        if let date = httpDate(raw) {
            return max(0, date.timeIntervalSince(now))
        }
        return nil
    }

    /// HTTP-date form of `Retry-After`, for Providers that send it instead of
    /// a number of seconds. RFC 1123 is the preferred HTTP-date format.
    private static func httpDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: string)
    }
}
