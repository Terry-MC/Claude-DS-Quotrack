import Foundation
import Security
import Testing

struct KeychainQueryTests {
    @Test
    func baseQueryTargetsTheDataProtectionKeychainByServiceAndAccountUUID() {
        let accountID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let query = KeychainQuery(
            service: "com.terry.quotrack",
            accountID: accountID
        ).baseQuery

        #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(query[kSecAttrService as String] as? String == "com.terry.quotrack")
        #expect(query[kSecAttrAccount as String] as? String == accountID.uuidString)
        #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
    }

    @Test
    func newCredentialsAreAccessibleAfterFirstUnlock() {
        let accountID = UUID()
        let query = KeychainQuery(
            service: "com.terry.quotrack",
            accountID: accountID
        ).addQuery(credential: "sk-very-secret")

        #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
        #expect(
            query[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleAfterFirstUnlock as String
        )
        #expect(query[kSecValueData as String] as? Data == Data("sk-very-secret".utf8))
    }
}
