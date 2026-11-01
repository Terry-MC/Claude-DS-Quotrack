import Foundation

/// One outbound HTTP request. Adapters build these so their tests can inspect
/// the URL, method, and headers without a network layer.
struct HTTPRequest: Equatable, Sendable {
    let url: URL
    let method: String
    let headers: [String: String]
    let body: Data?

    init(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

/// One HTTP response, including non-2xx statuses. URLSession does not throw on
/// an HTTP error status, so adapters map status codes themselves.
struct HTTPResponse: Equatable, Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    /// Header lookup is case-insensitive because HTTP header names are.
    func header(_ name: String) -> String? {
        if let exact = headers[name] {
            return exact
        }
        return headers.first {
            $0.key.caseInsensitiveCompare(name) == .orderedSame
        }?.value
    }
}

/// The thin network seam every Provider adapter depends on. Production uses
/// `URLSessionTransport`; adapter tests inject a stub and never touch the
/// network.
protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// The production transport. It uses an ephemeral, cache-free URLSession with a
/// 15-second timeout. `connectionProxyDictionary` is deliberately left unset,
/// so URLSession honors the system proxy settings (User Story 45).
struct URLSessionTransport: HTTPTransport {
    static let timeout: TimeInterval = 15

    let configuration: URLSessionConfiguration
    private let session: URLSession

    init(configuration: URLSessionConfiguration = .ephemeral) {
        let configuration = configuration.copy() as? URLSessionConfiguration ?? configuration
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.timeoutIntervalForResource = Self.timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        self.configuration = configuration
        self.session = URLSession(configuration: configuration)
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(
            url: request.url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Self.timeout
        )
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BalanceProviderError.malformedResponse
        }
        var headers: [String: String] = [:]
        for (name, value) in httpResponse.allHeaderFields {
            if let name = name as? String, let value = value as? String {
                headers[name] = value
            }
        }
        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            body: data
        )
    }
}
