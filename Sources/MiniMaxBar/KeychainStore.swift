import Foundation
import Security

enum KeychainStore {
    private static let service = "com.minimaxi.usage"
    private static let account = "api_key"

    /// 生产配置走 Apple 标准 keychain(配合 Developer ID 签名 + 首次"Always Allow")
    /// DEBUG 走 Data Protection Keychain,避免 ad-hoc 签名 + dist/ 重建 bundle 时反复弹授权框
    /// 用函数返回值而不是 static let,绕开 Swift 6 严格并发对 [String: Any] 的检查
    private static func extraAttrs() -> [String: Any] {
        #if DEBUG
        return [kSecUseDataProtectionKeychain as String: true]
        #else
        return [:]
        #endif
    }

    static func save(_ key: String) {
        let data = Data(key.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete((baseQuery.merging(extraAttrs()) { _, new in new }) as CFDictionary)
        var attributes = baseQuery.merging(extraAttrs()) { _, new in new }
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("Keychain save failed: \(status)")
        }
    }

    static func load() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        query.merge(extraAttrs()) { _, new in new }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        query.merge(extraAttrs()) { _, new in new }
        SecItemDelete(query as CFDictionary)
    }
}
