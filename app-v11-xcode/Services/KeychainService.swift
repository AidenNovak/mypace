//
//  KeychainService.swift
//  MyPace
//
//  Keychain 凭证管理 + 闪电说凭证读取。
//  ==========================================
//  闪电说集成原理：
//  闪电说把火山引擎凭证存在它自己的 Keychain entry 里：
//    service: com.shandianshuo.mac
//    account: volcengine.{appid|access_token}
//
//  我们用 SecItemCopyMatching 直接读取（需要相同的 access group）。
//  注意：实际接入需要测试，闪电说的 entry 结构可能不一样。
//

import Foundation
import Security

enum KeychainService {

    // MARK: - MyPace 自己的凭证存取

    private static let myPaceService = "ai.mypace.MyPace"
    private static let volcAppIDKey = "volc.app_id"
    private static let volcTokenKey = "volc.access_token"

    /// 保存火山引擎凭证（用户在设置里手动输入）
    static func saveVolcengineCredentials(appID: String, accessToken: String) throws {
        try save(myPaceService, key: volcAppIDKey, value: appID)
        try save(myPaceService, key: volcTokenKey, value: accessToken)
    }

    /// 读取已保存的火山引擎凭证
    static func loadVolcengineCredentials() -> (appID: String, accessToken: String)? {
        guard let appID = load(myPaceService, key: volcAppIDKey),
              let token = load(myPaceService, key: volcTokenKey),
              !appID.isEmpty, !token.isEmpty else { return nil }
        return (appID, token)
    }

    /// 清除凭证（用户在设置里点"清除"）
    static func clearVolcengineCredentials() {
        delete(myPaceService, key: volcAppIDKey)
        delete(myPaceService, key: volcTokenKey)
    }

    // MARK: - 闪电说凭证导入

    /// 检测本机是否安装闪电说
    static func isShandianshuoInstalled() -> Bool {
        let apps = [
            "/Applications/闪电说.app",
            "/Applications/Shandianshuo.app",
            NSHomeDirectory() + "/Applications/闪电说.app"
        ]
        return apps.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// 尝试从闪电说的 Keychain 读取凭证
    /// 返回 nil 表示未安装或没找到（需要降级到手动输入）
    ///
    /// ⚠️ 注意：本函数目前是"占位实现"。
    /// 真正接入需要：
    ///   1. 跟闪电说作者确认 Keychain entry 的 service / account 命名
    ///   2. 共享 access group（需要苹果 App Group entitlement）
    ///   3. 或者用 URL Scheme / Custom Pasteboard 跨 app 通信
    static func importFromShandianshuo() -> (appID: String, accessToken: String)? {
        guard isShandianshuoInstalled() else { return nil }

        // 占位：实际项目里这里要 SecItemCopyMatching with kSecAttrAccessGroup
        let shandianshuoService = "com.shandianshuo.mac"
        let appID = load(shandianshuoService, key: "volcengine.app_id")
        let token = load(shandianshuoService, key: "volcengine.access_token")

        guard let id = appID, let t = token, !id.isEmpty, !t.isEmpty else {
            return nil
        }

        // 导入到 MyPace 自己的 Keychain（避免每次都跨 app 读）
        try? saveVolcengineCredentials(appID: id, accessToken: t)
        return (id, t)
    }

    // MARK: - 底层 Keychain 操作

    private static func save(_ service: String, key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // 先删除旧值
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.systemError(status: status)
        }
    }

    private static func load(_ service: String, key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    @discardableResult
    private static func delete(_ service: String, key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

enum KeychainError: LocalizedError {
    case invalidData
    case systemError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:                   "无效的数据"
        case .systemError(let s):            "Keychain 错误: \(s)"
        }
    }
}
