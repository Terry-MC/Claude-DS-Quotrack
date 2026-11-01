import Foundation
import Testing

/// Tests the URLSession-backed transport only. `URLProtocol` intercepts before
/// any socket or proxy is used, so these tests never touch the network; adapter
/// tests use the lighter `StubHTTPTransport` instead.
struct URLSessionTransportTests {
    @Test
    func sendsTheRequestAndReturnsTheStatusHeadersAndBody() async throws {
        let url = URL(string: "https://transport.test/deepseek/balance")!
        URLSessionTestStub.register(
            url: url,
            statusCode: 429,
            headers: ["Retry-After": "120"],
            body: Data(#"{"retry":true}"#.utf8)
        )
        let transport = URLSessionTransport(configuration: .stubbed())

        let response = try await transport.send(
            HTTPRequest(
                url: url,
                headers: ["Authorization": "Bearer sk-test"]
            )
        )

        #expect(response.statusCode == 429)
        #expect(response.header("Retry-After") == "120")
        #expect(response.body == Data(#"{"retry":true}"#.utf8))

        let request = try #require(URLSessionTestStub.requests(for: url).first)
        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    }

    @Test
    func usesAnEphemeralFifteenSecondConfigurationWithoutACustomProxy() {
        let configuration = URLSessionTransport().configuration

        #expect(configuration.timeoutIntervalForRequest == 15)
        #expect(configuration.timeoutIntervalForResource == 15)
        #expect(configuration.urlCache == nil)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.connectionProxyDictionary == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test
    func transportFailuresPropagateAsURLErrors() async {
        let url = URL(string: "https://transport.test/offline")!
        URLSessionTestStub.register(
            url: url,
            error: URLError(.notConnectedToInternet)
        )
        let transport = URLSessionTransport(configuration: .stubbed())

        await #expect(throws: URLError.self) {
            try await transport.send(HTTPRequest(url: url))
        }
    }
}

/// Adds a URLProtocol stub to an ephemeral configuration. The stub registry is
/// keyed by URL and lock-protected, so tests running in parallel never share
/// response state.
extension URLSessionConfiguration {
    static func stubbed() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLSessionTestStub.self]
        return configuration
    }
}

final class URLSessionTestStub: URLProtocol {
    struct Stub {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
        let error: (any Error)?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubs: [URL: Stub] = [:]
    nonisolated(unsafe) private static var recordedRequests: [URL: [URLRequest]] = [:]

    static func register(
        url: URL,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data(),
        error: (any Error)? = nil
    ) {
        lock.withLock {
            stubs[url] = Stub(
                statusCode: statusCode,
                headers: headers,
                body: body,
                error: error
            )
        }
    }

    static func requests(for url: URL) -> [URLRequest] {
        lock.withLock { recordedRequests[url] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let stub = Self.stub(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.record(request, for: url)

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func stub(for url: URL) -> Stub? {
        lock.withLock { stubs[url] }
    }

    private static func record(_ request: URLRequest, for url: URL) {
        lock.withLock { recordedRequests[url, default: []].append(request) }
    }
}
