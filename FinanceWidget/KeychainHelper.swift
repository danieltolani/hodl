// KeychainHelper.swift
// Shared between the host app and the Widget Extension.
//
// Stores two secrets:
//   • notionTokenKey   — Notion integration secret ("secret_…")
//   • databaseIdKey    — 32-char Notion database ID for the current month
//
// The monthly spend limit is NOT stored here; it lives in the widget's
// AppIntent configuration (long-press → Edit Widget → Monthly Spend Limit).
//
// App Group Keychain sharing
// ───────────────────────────
// The Widget Extension runs in a separate sandbox from the host app.
// To share Keychain items across both targets, pass the same access group
// string (matching the one configured in Signing & Capabilities →
// Keychain Sharing for both targets, e.g. "group.com.yourcompany.hodl")
// when calling save/load.  If credentials are only ever written from within
// the extension, you can omit accessGroup.

import Foundation
import Security

public enum KeychainHelper {

    public static let service           = "com.hodl.financewidget"
    /// App Group shared between the host app and the widget extension.
    /// Must match the group configured in Signing & Capabilities for both targets.
    public static let sharedAccessGroup = "group.dnx.Hodl"

    // MARK: - Well-known key constants

    /// Notion internal integration secret (starts with "secret_…").
    public static let notionTokenKey = "notionToken"

    /// 32-char ID of the current month's "{MONTH} FIGURES (NGN)" database.
    public static let databaseIdKey  = "notionDatabaseId"

    // MARK: - Save

    @discardableResult
    public static func save(key: String, value: String, accessGroup: String? = sharedAccessGroup) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        var query = baseQuery(key: key, accessGroup: accessGroup)

        let updateAttrs: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttrs as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            query[kSecValueData] = data
            return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
        default:
            return false
        }
    }

    // MARK: - Load

    public static func load(key: String, accessGroup: String? = sharedAccessGroup) -> String? {
        var query = baseQuery(key: key, accessGroup: accessGroup)
        query[kSecReturnData]  = true
        query[kSecMatchLimit]  = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data   = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    // MARK: - Delete

    @discardableResult
    public static func delete(key: String, accessGroup: String? = sharedAccessGroup) -> Bool {
        let query  = baseQuery(key: key, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Private

    private static func baseQuery(key: String, accessGroup: String?) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup] = group
        }
        return query
    }
}
