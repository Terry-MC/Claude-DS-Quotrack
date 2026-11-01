import Foundation
import Security
import Testing

struct KeychainQueryTests {
    private let accountID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    @Test
    func dataProtectionQueriesCarryTheFlagAndAccessibility() {
        let query = KeychainQuery(
            service: "com.terry.quotrack",
            accountID: accountID,
            usesDataProtectionKeychain: true
        )

        let base = query.baseQuery
        #expect(base[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(base[kSecAttrService as String] as? String == "com.terry.quotrack")
        #expect(base[kSecAttrAccount as String] as? String == accountID.uuidString)
        #expect(base[kSecUseDataProtectionKeychain as String] as? Bool == true)

        let add = query.addQuery(credential: "sk-very-secret")
        #expect(
            add[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleAfterFirstUnlock as String
        )
        #expect(add[kSecValueData as String] as? Data == Data("sk-very-secret".utf8))
    }

    @Test
    func legacyQueriesOmitTheDataProtectionFlagAndAccessibility() {
        let query = KeychainQuery(
            service: "com.terry.quotrack",
            accountID: accountID,
            usesDataProtectionKeychain: false
        )

        #expect(query.baseQuery[kSecUseDataProtectionKeychain as String] == nil)

        let add = query.addQuery(credential: "sk-very-secret")
        #expect(add[kSecAttrAccessible as String] == nil)
        #expect(add[kSecValueData as String] as? Data == Data("sk-very-secret".utf8))
    }
}
