import Foundation

/// A scripted HTTPTransport for adapter tests. It records every request and
/// returns or throws the prepared outcome, so adapter tests never touch the
/// network. The recorded requests are lock-protected because Swift Testing runs
/// tests in parallel.
final class StubHTTPTransport: HTTPTransport, @unchecked Sendable {
    private enum Outcome {
        case response(HTTPResponse)
        case failure(any Error)
    }

    private let lock = NSLock()
    private let outcome: Outcome
    private var recordedRequests: [HTTPRequest] = []

    init(response: HTTPResponse) {
        self.outcome = .response(response)
    }

    init(error: any Error) {
        self.outcome = .failure(error)
    }

    var requests: [HTTPRequest] {
        lock.withLock { recordedRequests }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { recordedRequests.append(request) }
        switch outcome {
        case let .response(response):
            return response
        case let .failure(error):
            throw error
        }
    }
}

extension HTTPResponse {
    /// Builds a JSON response fixture. Fixtures live as literals in the tests,
    /// so an API shape change fails a test instead of silently updating data.
    static func json(
        status: Int = 200,
        body: String,
        headers: [String: String] = [:]
    ) -> HTTPResponse {
        var allHeaders = headers
        allHeaders["Content-Type"] = "application/json"
        return HTTPResponse(
            statusCode: status,
            headers: allHeaders,
            body: Data(body.utf8)
        )
    }
}
