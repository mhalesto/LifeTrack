//
//  KeychainStore.swift
//  LifeTrack
//
//  Minimal Keychain wrapper for storing small string secrets
//  (API keys, tokens). Items are scoped to the app and not
//  synced to iCloud.
//

import Foundation
import Security

enum KeychainStore {
    private static let service = "com.currenttech.LifeTrack"

    static func setString(_ value: String?, account: String) {
        guard let value, !value.isEmpty else {
            delete(account: account)
            return
        }
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            for (key, value) in attributes { insert[key] = value }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    static func string(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Single source of truth for the Claude API key. Reads from Keychain,
/// migrating any pre-existing UserDefaults value on first access, then
/// clears the UserDefaults copy so it never sits in plain text again.
enum ClaudeAPIKeyStore {
    private static let account = "claude.api.key"
    private static let migrationFlagKey = "LifeTrack.settings.claudeAPIKeyMigrated"

    static var current: String {
        migrateIfNeeded()
        return KeychainStore.string(account: account) ?? ""
    }

    static func set(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainStore.setString(trimmed, account: account)
        UserDefaults.standard.removeObject(forKey: LifeTrackSettings.Keys.claudeAPIKey)
        UserDefaults.standard.set(true, forKey: migrationFlagKey)
    }

    private static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationFlagKey) else { return }
        if let legacy = defaults.string(forKey: LifeTrackSettings.Keys.claudeAPIKey),
           !legacy.isEmpty,
           KeychainStore.string(account: account) == nil {
            KeychainStore.setString(legacy, account: account)
        }
        defaults.removeObject(forKey: LifeTrackSettings.Keys.claudeAPIKey)
        defaults.set(true, forKey: migrationFlagKey)
    }
}
