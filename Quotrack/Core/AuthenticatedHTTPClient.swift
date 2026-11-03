import Foundation

/// Shared HTTP plumbing for authenticated balance adapters. It owns the Bearer
/// header, Keychain lookup, transport classification, and non-2xx mapping, so
/// an adapter only supplies its endpoint and response decoding.
struct AuthenticatedHTTPClient: Sendable {
    private let transport: any HTTPTransport
    private let credentialStore: any CredentialStore
    private let unauthorized: BalanceProviderError
    private let now: @Sendable () -> Date

    init(
        transport: any HTTPTransport,
        credentialStore: any CredentialStore,
        unauthorized: BalanceProviderError = .authentication,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.credentialStore = credentialStore
        self.unauthorized = unauthorized
        self.now = now
    }

    /// Fetches with the Account's saved credential. A missing or unreadable
    /// credential fails as authentication without an HTTP call.
    func get(_ url: URL, accountID: Account.ID) async throws -> HTTPResponse {
        try await get(url, credential: credential(for: accountID))
    }

    /// Fetches with a credential that is not saved yet, used by the onboarding
    /// and Settings connection tests.
    func get(_ url: URL, credential: String) async throws -> HTTPResponse {
        let response = try await send(
            HTTPRequest(
                url: url,
                headers: [
                    "Authorization": "Bearer \(credential)",
                    "Accept": "application/json",
                ]
            )
        )
        guard (200..<300).contains(response.statusCode) else {
            throw ProviderHTTPErrorMapper.error(
                for: response,
                unauthorized: unauthorized,
                now: now()
            )
        }
        return response
    }

    private func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        do {
            return try await transport.send(request)
        } catch let error as BalanceProviderError {
            throw error
        } catch {
            // URLError and other transport failures become the shared network
            // category so the monitor never sees a raw Foundation error.
            throw BalanceProviderError.classify(error)
        }
    }

    private func credential(for accountID: Account.ID) throws -> String {
        do {
            guard
                let stored = try credentialStore.credential(for: accountID),
                !stored.isEmpty
            else {
                throw BalanceProviderError.authentication
            }
            return stored
        } catch let error as BalanceProviderError {
            throw error
        } catch let error as CredentialStoreError {
            throw BalanceProviderError(
                .authentication,
                detail: error.localizedDescription
            )
        } catch {
            throw BalanceProviderError.classify(error)
        }
    }
}
