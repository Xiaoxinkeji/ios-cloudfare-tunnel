// Core/TunnelModels.swift
// Data models shared across the app

import Foundation

// MARK: - TunnelInfo

/// Represents the live state of a single Cloudflare Tunnel returned by the API.
struct TunnelInfo: Codable, Equatable {
    let id: String
    let name: String
    let status: String
    let createdAt: Date?
    let healthcheck: Bool?

    // Cloudflare returns "healthy", "degraded", "down", "inactive", etc.
    var isRunning: Bool {
        status.lowercased() == "healthy" || status.lowercased() == "active"
    }
}

// MARK: - TunnelConfig

/// Persisted user configuration (stored in UserDefaults).
struct TunnelConfig: Codable {
    var tunnelId: String
    var accountId: String
    var baseURL: String

    static let `default` = TunnelConfig(
        tunnelId: "",
        accountId: "",
        baseURL: "https://api.cloudflare.com/client/v4"
    )
}

// MARK: - Cloudflare API envelope

/// Top-level wrapper for every Cloudflare v4 API response.
struct CloudflareResponse<T: Decodable>: Decodable {
    let result: T?
    let success: Bool
    let errors: [CloudflareAPIError]
}

struct CloudflareAPIError: Decodable {
    let code: Int
    let message: String
}
