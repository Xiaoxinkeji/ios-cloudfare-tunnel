// Core/Storage.swift
// Keychain helpers (API token) + UserDefaults helpers (TunnelConfig)

import Foundation
import Security

// MARK: - Storage

enum Storage {

    // ──────────────────────────────────────────────────
    // MARK: Keychain – API Token
    // ──────────────────────────────────────────────────

    private static let tokenService = "com.xiaoxinkeji.cloudfare-tunnel"
    private static let tokenAccount = "cloudflare-api-token"

    /// Persists the Bearer token in the device Keychain.
    static func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw StorageError.encodingFailed
        }

        // Delete any existing item first to avoid `errSecDuplicateItem`.
        try? deleteToken()

        let query: [String: Any] = [
            kSecClass            as String: kSecClassGenericPassword,
            kSecAttrService      as String: tokenService,
            kSecAttrAccount      as String: tokenAccount,
            kSecValueData        as String: data,
            kSecAttrAccessible   as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StorageError.keychainError(status)
        }
    }

    /// Reads the Bearer token from the device Keychain.
    /// - Throws: `StorageError.tokenNotFound` if no token has been saved yet.
    static func loadToken() throws -> String {
        let query: [String: Any] = [
            kSecClass            as String: kSecClassGenericPassword,
            kSecAttrService      as String: tokenService,
            kSecAttrAccount      as String: tokenAccount,
            kSecReturnData       as String: true,
            kSecMatchLimit       as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw StorageError.tokenNotFound
            }
            throw StorageError.keychainError(status)
        }

        guard
            let data = item as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw StorageError.decodingFailed
        }

        return token
    }

    /// Removes the Bearer token from the Keychain.
    static func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.keychainError(status)
        }
    }

    // ──────────────────────────────────────────────────
    // MARK: UserDefaults – TunnelConfig
    // ──────────────────────────────────────────────────

    private static let configKey = "tunnelConfig"

    /// Encodes and stores `TunnelConfig` in `UserDefaults.standard`.
    static func saveConfig(_ config: TunnelConfig) {
        guard let data = try? JSONEncoder.cloudflare.encode(config) else { return }
        UserDefaults.standard.set(data, forKey: configKey)
    }

    /// Loads and decodes `TunnelConfig` from `UserDefaults.standard`.
    /// Returns `nil` if nothing has been saved yet.
    static func loadConfig() -> TunnelConfig? {
        guard
            let data = UserDefaults.standard.data(forKey: configKey),
            let config = try? JSONDecoder.cloudflare.decode(TunnelConfig.self, from: data)
        else {
            return nil
        }
        return config
    }
}

// MARK: - StorageError

enum StorageError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case tokenNotFound
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode the token for storage."
        case .decodingFailed:
            return "Failed to decode the token from storage."
        case .tokenNotFound:
            return "No API token found. Please add your Cloudflare API Token in Settings."
        case .keychainError(let status):
            return "Keychain error (OSStatus \(status))."
        }
    }
}
