import Foundation
import Security

/// The persistence seam for Account credentials. `KeychainCredentialStore` is
/// the only production store; tests substitute an in-memory fake so no test
/// touches the real Keychain. Credentials never live on `Account` or on disk.
protocol CredentialStore: Sendable {
    /// Creates or replaces the credential for an Account.
    func save(_ credential: String, for accountID: Account.ID) throws
    /// Reads a credential for a Provider query. Settings must never render it.
    func credential(for accountID: Account.ID) throws -> String?
    /// Removes the credential. Deleting a missing credential succeeds.
    func deleteCredential(for accountID: Account.ID) throws
}

enum CredentialStoreError: Error, Equatable, LocalizedError {
    case interactionNotAllowed
    case malformedCredential
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .interactionNotAllowed:
            "钥匙串已锁定，解锁 Mac 后重试。"
        case .malformedCredential:
            "钥匙串中的凭证格式无效。"
        case let .keychain(status):
            SecCopyErrorMessageString(status, nil) as String? ?? "钥匙串错误（\(status)）。"
        }
    }
}

/// Builds the Security framework queries for one Account's generic-password
/// item. `kSecUseDataProtectionKeychain` is required: without it macOS uses
/// the legacy file keychain, ignores accessibility, and may show ACL prompts.
struct KeychainQuery: Sendable {
    let service: String
    let accountID: Account.ID

    var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    func addQuery(credential: String) -> [String: Any] {
        var query = baseQuery
        query.merge(credentialAttributes(credential)) { _, new in new }
        return query
    }

    func credentialAttributes(_ credential: String) -> [String: Any] {
        [
            kSecValueData as String: Data(credential.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock as String,
        ]
    }
}

/// Stores credentials as generic passwords in the macOS Keychain: service is
/// the bundle identifier, account is the Account UUID, accessibility is after
/// first unlock, and synchronization with iCloud is never enabled.
struct KeychainCredentialStore: CredentialStore {
    let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.terry.quotrack") {
        self.service = service
    }

    func save(_ credential: String, for accountID: Account.ID) throws {
        let query = KeychainQuery(service: service, accountID: accountID)
        let attributes = query.credentialAttributes(credential)
        let status = SecItemUpdate(query.baseQuery as CFDictionary, attributes as CFDictionary)

        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addStatus = SecItemAdd(
                query.addQuery(credential: credential) as CFDictionary,
                nil
            )
            if addStatus == errSecDuplicateItem {
                let retryStatus = SecItemUpdate(
                    query.baseQuery as CFDictionary,
                    attributes as CFDictionary
                )
                guard retryStatus == errSecSuccess else {
                    throw Self.error(for: retryStatus)
                }
            } else if addStatus != errSecSuccess {
                throw Self.error(for: addStatus)
            }
        default:
            throw Self.error(for: status)
        }
    }

    func credential(for accountID: Account.ID) throws -> String? {
        var query = KeychainQuery(service: service, accountID: accountID).baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne as String

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let credential = String(data: data, encoding: .utf8)
            else {
                throw CredentialStoreError.malformedCredential
            }
            return credential
        case errSecItemNotFound:
            return nil
        default:
            throw Self.error(for: status)
        }
    }

    func deleteCredential(for accountID: Account.ID) throws {
        let query = KeychainQuery(service: service, accountID: accountID).baseQuery
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Self.error(for: status)
        }
    }

    private static func error(for status: OSStatus) -> CredentialStoreError {
        status == errSecInteractionNotAllowed ? .interactionNotAllowed : .keychain(status)
    }
}
