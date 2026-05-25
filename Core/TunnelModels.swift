// Core/TunnelModels.swift
// Data models shared across the app

import Foundation

// MARK: - TunnelLogEntry

/// A single log line emitted by the tunnel or the app layer.
struct TunnelLogEntry: Codable, Identifiable, Equatable {
    var id: String { "\(timestamp)-\(message)" }
    let timestamp: Date
    let message: String
}

// MARK: - TunnelInfo

/// Represents the live state of a single Cloudflare Tunnel returned by the API.
struct TunnelInfo: Codable, Equatable {
    let id: String
    let name: String
    let status: String
    let createdAt: Date?
    let healthcheck: Bool?

    /// Optional narrative summary returned by the API (e.g. "All connectors healthy").
    var healthSummary: String?

    /// Recent log entries associated with this tunnel (populated locally; not from API).
    var logLines: [TunnelLogEntry]

    // MARK: - Custom Codable

    // `logLines` is a local-only field and should not be encoded/decoded from the API
    // response.  We handle it manually so the JSON keys remain clean.
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case createdAt
        case healthcheck
        case healthSummary
        // logLines intentionally omitted from CodingKeys
    }

    init(
        id: String,
        name: String,
        status: String,
        createdAt: Date? = nil,
        healthcheck: Bool? = nil,
        healthSummary: String? = nil,
        logLines: [TunnelLogEntry] = []
    ) {
        self.id            = id
        self.name          = name
        self.status        = status
        self.createdAt     = createdAt
        self.healthcheck   = healthcheck
        self.healthSummary = healthSummary
        self.logLines      = logLines
    }

    init(from decoder: Decoder) throws {
        let container  = try decoder.container(keyedBy: CodingKeys.self)
        id             = try container.decode(String.self, forKey: .id)
        name           = try container.decode(String.self, forKey: .name)
        status         = try container.decode(String.self, forKey: .status)
        createdAt      = try container.decodeIfPresent(Date.self,   forKey: .createdAt)
        healthcheck    = try container.decodeIfPresent(Bool.self,   forKey: .healthcheck)
        healthSummary  = try container.decodeIfPresent(String.self, forKey: .healthSummary)
        logLines       = []          // always starts empty; populated by the view-model
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id,            forKey: .id)
        try container.encode(name,          forKey: .name)
        try container.encode(status,        forKey: .status)
        try container.encodeIfPresent(createdAt,     forKey: .createdAt)
        try container.encodeIfPresent(healthcheck,   forKey: .healthcheck)
        try container.encodeIfPresent(healthSummary, forKey: .healthSummary)
    }

    // Cloudflare returns "healthy", "degraded", "down", "inactive", etc.
    var isRunning: Bool {
        status.lowercased() == "healthy" || status.lowercased() == "active"
    }

    // MARK: - Equatable

    static func == (lhs: TunnelInfo, rhs: TunnelInfo) -> Bool {
        lhs.id            == rhs.id
        && lhs.name       == rhs.name
        && lhs.status     == rhs.status
        && lhs.createdAt  == rhs.createdAt
        && lhs.healthcheck == rhs.healthcheck
        && lhs.healthSummary == rhs.healthSummary
        && lhs.logLines   == rhs.logLines
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
