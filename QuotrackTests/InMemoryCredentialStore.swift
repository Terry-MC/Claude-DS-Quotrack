import Foundation

/// A thread-safe CredentialStore for tests. It keeps credentials in memory, so
/// no test ever reads or writes the real Keychain.
final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var credentials: [Account.ID: String]
    private(set) var saveCallCount = 0
    private(set) var deleteCallCount = 0
    var saveError: (any Error)?
    var readError: (any Error)?
    var deleteError: (any Error)?

    init(credentials: [Account.ID: String] = [:]) {
        self.credentials = credentials
    }

    func save(_ credential: String, for accountID: Account.ID) throws {
        if let saveError {
            throw saveError
        }
        lock.withLock {
            saveCallCount += 1
            credentials[accountID] = credential
        }
    }

    func credential(for accountID: Account.ID) throws -> String? {
        if let readError {
            throw readError
        }
        return lock.withLock { credentials[accountID] }
    }

    func deleteCredential(for accountID: Account.ID) throws {
        if let deleteError {
            throw deleteError
        }
        lock.withLock {
            deleteCallCount += 1
            credentials[accountID] = nil
        }
    }
}
