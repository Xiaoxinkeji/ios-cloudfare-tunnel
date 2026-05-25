// Core/TunnelModels.swift
import Foundation

// MARK: - Configuration

struct TunnelConfiguration: Codable, Equatable {
    var cloudflareAPIBaseURL: URL
    var controlPlaneURL: URL?
    var accountId: String
    var tunnelId: String?
    var cloudflareAuthMode: CloudflareManagementAuthMode
    var controlPlaneAuthMode: ControlPlaneAuthMode

    static let defaultValue = TunnelConfiguration(
        cloudflareAPIBaseURL: URL(string: "https://api.cloudflare.com")!,
        controlPlaneURL: URL(string: "https://control.example.com"),
        accountId: "",
        tunnelId: nil,
        cloudflareAuthMode: .apiToken,
        controlPlaneAuthMode: .none
    )
}

// MARK: - Legacy alias retained for backwards compatibility

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

// MARK: - API Envelope

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let errors: [APIMessage]
    let messages: [APIMessage]
    let result: T
}

struct APIMessage: Codable, Equatable {
    let code: Int?
    let message: String
    let documentationURL: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case documentationURL = "documentation_url"
    }
}

// MARK: - Cloudflare Tunnel Domain Models

struct CloudflareTunnel: Codable, Equatable {
    let id: String
    let accountTag: String
    let configSrc: String?
    let connsActiveAt: Date?
    let connsInactiveAt: Date?
    let createdAt: Date?
    let deletedAt: Date?
    let metadata: [String: String]?
    let name: String
    let remoteConfig: Bool?
    let status: String?
    let tunType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case accountTag = "account_tag"
        case configSrc = "config_src"
        case connsActiveAt = "conns_active_at"
        case connsInactiveAt = "conns_inactive_at"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
        case metadata
        case name
        case remoteConfig = "remote_config"
        case status
        case tunType = "tun_type"
    }
}

struct TunnelConnectionClient: Codable, Equatable {
    let id: String
    let arch: String?
    let configVersion: Int?
    let conns: [TunnelEdgeConnection]
    let features: [String]
    let runAt: Date?
    let version: String?

    enum CodingKeys: String, CodingKey {
        case id, arch, conns, features, version
        case configVersion = "config_version"
        case runAt = "run_at"
    }
}

struct TunnelEdgeConnection: Codable, Equatable {
    let id: String
    let clientId: String?
    let clientVersion: String?
    let coloName: String?
    let isPendingReconnect: Bool?
    let openedAt: Date?
    let originIP: String?
    let uuid: String?

    enum CodingKeys: String, CodingKey {
        case id, uuid
        case clientId = "client_id"
        case clientVersion = "client_version"
        case coloName = "colo_name"
        case isPendingReconnect = "is_pending_reconnect"
        case openedAt = "opened_at"
        case originIP = "origin_ip"
    }
}

struct TunnelRemoteConfig: Codable, Equatable {
    let config: TunnelIngressConfig
}

struct TunnelIngressConfig: Codable, Equatable {
    let ingress: [TunnelIngressRule]
}

struct TunnelIngressRule: Codable, Equatable {
    let hostname: String?
    let service: String
    let originRequest: [String: String]?
}

// MARK: - Runtime Tunnel Status (control backend)

struct RuntimeTunnelStatus: Codable, Equatable {
    let state: TunnelStateDTO
    let title: String
    let subtitle: String
    let updatedAt: Date?
    let logs: [String]?
    let healthcheck: String?
}

enum TunnelStateDTO: String, Codable, Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failure
}

// MARK: - Aggregated UI Status

struct TunnelStatus: Equatable {
    var state: TunnelState
    var title: String
    var subtitle: String
    var lastUpdatedAt: Date?
    var healthSummary: String
    var logLines: [String]
    var tunnel: CloudflareTunnel?
    var connections: [TunnelConnectionClient]

    var info: TunnelInfo? {
        guard case .connected(let info) = state else { return nil }
        return info
    }

    static let idle = TunnelStatus(
        state: .disconnected,
        title: "Not connected",
        subtitle: "Set backend details to control your tunnel.",
        lastUpdatedAt: nil,
        healthSummary: "Unknown",
        logLines: [],
        tunnel: nil,
        connections: []
    )

    static func disconnected(message: String, updatedAt: Date?) -> TunnelStatus {
        TunnelStatus(state: .disconnected, title: "Not connected", subtitle: message, lastUpdatedAt: updatedAt, healthSummary: "Offline", logLines: [], tunnel: nil, connections: [])
    }

    static func connecting(message: String, updatedAt: Date?) -> TunnelStatus {
        TunnelStatus(state: .connecting, title: "Connecting", subtitle: message, lastUpdatedAt: updatedAt, healthSummary: "Starting", logLines: [], tunnel: nil, connections: [])
    }

    static func connected(info: TunnelInfo, title: String, subtitle: String, updatedAt: Date?, healthSummary: String, logLines: [String], tunnel: CloudflareTunnel?, connections: [TunnelConnectionClient]) -> TunnelStatus {
        TunnelStatus(state: .connected(info: info), title: title, subtitle: subtitle, lastUpdatedAt: updatedAt, healthSummary: healthSummary, logLines: logLines, tunnel: tunnel, connections: connections)
    }

    static func disconnecting(message: String, updatedAt: Date?) -> TunnelStatus {
        TunnelStatus(state: .disconnecting, title: "Disconnecting", subtitle: message, lastUpdatedAt: updatedAt, healthSummary: "Stopping", logLines: [], tunnel: nil, connections: [])
    }

    static func failure(message: String, updatedAt: Date?) -> TunnelStatus {
        TunnelStatus(state: .failure(error: .unknown(message: message)), title: "Connection failed", subtitle: message, lastUpdatedAt: updatedAt, healthSummary: "Error", logLines: [message], tunnel: nil, connections: [])
    }
}

// MARK: - Legacy TunnelInfo / log entry retained for current views

struct TunnelLogEntry: Codable, Identifiable, Equatable {
    var id: String { "\(timestamp)-\(message)" }
    let timestamp: Date
    let message: String
}

struct TunnelInfo: Codable, Equatable {
    let id: String
    let name: String
    let status: String
    let createdAt: Date?
    let healthcheck: Bool?
    var healthSummary: String?
    var logLines: [TunnelLogEntry]

    private enum CodingKeys: String, CodingKey {
        case id, name, status, createdAt, healthcheck, healthSummary
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
        self.id = id
        self.name = name
        self.status = status
        self.createdAt = createdAt
        self.healthcheck = healthcheck
        self.healthSummary = healthSummary
        self.logLines = logLines
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        status = try c.decode(String.self, forKey: .status)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        healthcheck = try c.decodeIfPresent(Bool.self, forKey: .healthcheck)
        healthSummary = try c.decodeIfPresent(String.self, forKey: .healthSummary)
        logLines = []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(healthcheck, forKey: .healthcheck)
        try c.encodeIfPresent(healthSummary, forKey: .healthSummary)
    }

    var isRunning: Bool {
        status.lowercased() == "healthy" || status.lowercased() == "active"
    }

    static func == (lhs: TunnelInfo, rhs: TunnelInfo) -> Bool {
        lhs.id == rhs.id
        && lhs.name == rhs.name
        && lhs.status == rhs.status
        && lhs.createdAt == rhs.createdAt
        && lhs.healthcheck == rhs.healthcheck
        && lhs.healthSummary == rhs.healthSummary
        && lhs.logLines == rhs.logLines
    }
}
