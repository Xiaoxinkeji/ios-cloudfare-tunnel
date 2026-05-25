// Core/Models/DNSRecord.swift
import Foundation

// MARK: - DNS Record Type

enum DNSRecordType: String, Codable, CaseIterable {
    case a     = "A"
    case cname = "CNAME"
    case txt   = "TXT"

    var displayName: String { rawValue }
}

// MARK: - Cloudflare API Envelope

struct CloudflareAPIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let errors: [CloudflareAPIMessage]
    let messages: [CloudflareAPIMessage]
    let result: T
}

struct CloudflareAPIMessage: Decodable, Equatable {
    let code: Int?
    let message: String
    let documentationURL: String?

    enum CodingKeys: String, CodingKey {
        case code, message
        case documentationURL = "documentation_url"
    }
}

// MARK: - DNS Record

struct DNSRecord: Codable, Identifiable, Equatable {
    let id: String
    let zoneID: String?
    let zoneName: String?
    let name: String
    let type: DNSRecordType
    let content: String
    let proxied: Bool?
    let ttl: Int
    let comment: String?
    let createdOn: Date?
    let modifiedOn: Date?
    let proxiable: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, type, content, proxied, ttl, comment, proxiable
        case zoneID      = "zone_id"
        case zoneName    = "zone_name"
        case createdOn   = "created_on"
        case modifiedOn  = "modified_on"
    }

    /// Returns true if this CNAME points to a Cloudflare Tunnel edge endpoint.
    var isTunnelCNAME: Bool {
        type == .cname && content.hasSuffix(".cfargotunnel.com")
    }
}

// MARK: - DNS Record List Response

struct DNSRecordListResponse: Decodable {
    let result: [DNSRecord]
    let resultInfo: ResultInfo?

    enum CodingKeys: String, CodingKey {
        case result
        case resultInfo = "result_info"
    }
}

struct ResultInfo: Decodable, Equatable {
    let page: Int?
    let perPage: Int?
    let count: Int?
    let totalCount: Int?

    enum CodingKeys: String, CodingKey {
        case page, count
        case perPage    = "per_page"
        case totalCount = "total_count"
    }
}

// MARK: - Create / Update Request Bodies

struct CreateDNSRecordRequest: Encodable, Equatable {
    let type: DNSRecordType
    let name: String
    let content: String
    let ttl: Int
    let proxied: Bool?
    let comment: String?
}

struct UpdateDNSRecordRequest: Encodable, Equatable {
    let type: DNSRecordType
    let name: String
    let content: String
    let ttl: Int
    let proxied: Bool?
    let comment: String?
}

// MARK: - Helpers

extension CreateDNSRecordRequest {
    /// Convenience initialiser for a Tunnel CNAME record.
    /// - Parameters:
    ///   - hostname: The public hostname, e.g. `"app.example.com"`.
    ///   - tunnelID: The Cloudflare Tunnel UUID.
    static func tunnelCNAME(hostname: String, tunnelID: String) -> Self {
        CreateDNSRecordRequest(
            type: .cname,
            name: hostname,
            content: "\(tunnelID).cfargotunnel.com",
            ttl: 1,       // 1 = automatic TTL (Cloudflare-managed)
            proxied: true,
            comment: "Managed by Cloudflare Tunnel iOS app"
        )
    }
}
