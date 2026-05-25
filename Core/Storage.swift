// Core/Storage.swift
import Foundation
import Security

final class TunnelConfigurationStore {
    static let shared = TunnelConfigurationStore()

    private let key = "cloudflare-tunnel-configuration-v2"
    private let legacyKey = "cloudflare-tunnel-configuration"

    func save(_ configuration: TunnelConfiguration) throws {
        let data = try JSONEncoder.tunnelEncoder.encode(configuration)
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() throws -> TunnelConfiguration {
        if let data = UserDefaults.standard.data(forKey: key) {
            return try JSONDecoder.tunnelDecoder.decode(TunnelConfiguration.self, from: data)
        }

        if UserDefaults.standard.data(forKey: legacyKey) != nil {
            return .defaultValue
        }

        return .defaultValue
    }
}

final class TunnelCredentialStore {
    static let shared = TunnelCredentialStore()

    private let service = "ios-cloudfare-tunnel.v2"

    private enum Account: String {
        case cloudflareAPIToken = "cloudflare.api-token"
        case controlPlaneBearerToken = "control-plane.bearer-token"
        case controlPlaneServiceTokenID = "control-plane.service-token-id"
        case controlPlaneServiceTokenSecret = "control-plane.service-token-secret"
    }

    func saveCloudflareAPIToken(_ token: String) throws {
        try save(token, for: .cloudflareAPIToken)
    }

    func loadCloudflareAPIToken() throws -> String? {
        try load(for: .cloudflareAPIToken)
    }

    func saveControlPlaneBearerToken(_ token: String) throws {
        try save(token, for: .controlPlaneBearerToken)
    }

    func loadControlPlaneBearerToken() throws -> String? {
        try load(for: .controlPlaneBearerToken)
    }

    func saveControlPlaneServiceToken(clientId: String, clientSecret: String) throws {
        try save(clientId, for: .controlPlaneServiceTokenID)
        try save(clientSecret, for: .controlPlaneServiceTokenSecret)
    }

    func loadControlPlaneServiceToken() throws -> ControlPlaneServiceToken? {
        guard
            let clientId = try load(for: .controlPlaneServiceTokenID),
            let clientSecret = try load(for: .controlPlaneServiceTokenSecret)
        else {
            return nil
        }
        return ControlPlaneServiceToken(clientId: clientId, clientSecret: clientSecret)
    }

    func loadCloudflareCredentials() throws -> CloudflareManagementCredentials? {
        guard let apiToken = try loadCloudflareAPIToken(), !apiToken.isEmpty else {
            return nil
        }
        return CloudflareManagementCredentials(apiToken: apiToken)
    }

    func loadControlPlaneCredentials() throws -> ControlPlaneCredentials {
        ControlPlaneCredentials(
            bearerToken: try loadControlPlaneBearerToken(),
            serviceToken: try loadControlPlaneServiceToken()
        )
    }

    private func save(_ value: String, for account: Account) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func load(for account: Account) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return value
    }
}

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .invalidData:
            return "Stored credential is invalid."
        }
    }
}

// Backwards-compat shim used by older call sites; new code should use TunnelCredentialStore directly.
enum Storage {
    static func loadConfig() -> TunnelConfig? {
        nil
    }
    static func saveConfig(_ config: TunnelConfig) {
        // legacy no-op
    }
    static func loadToken() throws -> String {
        guard let token = try TunnelCredentialStore.shared.loadCloudflareAPIToken(), !token.isEmpty else {
            throw TunnelError.unauthorized
        }
        return token
    }
}
