import Foundation
import Testing

struct BalanceProviderErrorTests {
    @Test(arguments: BalanceProviderError.allCases)
    func typedErrorsKeepTheirCategory(error: BalanceProviderError) {
        #expect(BalanceProviderError.classify(error) == error)
    }

    @Test
    func rateLimitCarriesAnOptionalRetryAfterDelay() {
        let delayed = BalanceProviderError.rateLimit(retryAfter: 120)
        #expect(delayed.category == .rateLimit)
        #expect(delayed.retryAfter == 120)
        #expect(BalanceProviderError.rateLimit.retryAfter == nil)
    }

    @Test
    func classifyPreservesTheRetryAfterDelay() {
        let delayed = BalanceProviderError.rateLimit(retryAfter: 90)

        let classified = BalanceProviderError.classify(delayed)

        #expect(classified == delayed)
        #expect(classified.category == .rateLimit)
        #expect(classified.retryAfter == 90)
    }

    @Test
    func transportErrorsClassifyAsNetwork() {
        #expect(BalanceProviderError.classify(URLError(.notConnectedToInternet)) == .network)
        #expect(BalanceProviderError.classify(URLError(.timedOut)) == .network)
    }

    @Test
    func decodingErrorsClassifyAsMalformedResponse() {
        let error = DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "bad JSON")
        )
        #expect(BalanceProviderError.classify(error) == .malformedResponse)
    }

    @Test
    func unrecognizedErrorsClassifyAsUnknown() {
        #expect(BalanceProviderError.classify(NSError(domain: "test", code: 1)) == .unknown)
    }
}
