// Core/API/CloudflareDNSAPIProtocol.swift
import Foundation

// MARK: - Protocol

protocol CloudflareDNSAPIProtocol {
    /// List DNS records in a zone, optionally filtered by type and/or name.
    func listDNSRecords(zoneID: String, type: DNSRecordType?, name: String?) async throws -> [DNSRecord]

    /// Fetch a single DNS record by its ID.
    func getDNSRecord(zoneID: String, recordID: String) async throws -> DNSRecord

    /// Create a new DNS record.
    func createDNSRecord(zoneID: String, request: CreateDNSRecordRequest) async throws -> DNSRecord

    /// Replace a DNS record (PUT — full replacement).
    func updateDNSRecord(zoneID: String, recordID: String, request: UpdateDNSRecordRequest) async throws -> DNSRecord

    /// Delete a DNS record.
    func deleteDNSRecord(zoneID: String, recordID: String) async throws
}

// MARK: - DNS API endpoints reference (Cloudflare v4)
//
// GET    /client/v4/zones/{zone_id}/dns_records
//        Query params: type=A|CNAME|TXT  name=<hostname>  page=1  per_page=20
// GET    /client/v4/zones/{zone_id}/dns_records/{dns_record_id}
// POST   /client/v4/zones/{zone_id}/dns_records
// PUT    /client/v4/zones/{zone_id}/dns_records/{dns_record_id}
// PATCH  /client/v4/zones/{zone_id}/dns_records/{dns_record_id}
// DELETE /client/v4/zones/{zone_id}/dns_records/{dns_record_id}

// MARK: - Concrete implementation (stub)

final class CloudflareDNSAPIClient: CloudflareDNSAPIProtocol {

    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: () throws -> String

    init(
        baseURL: URL = URL(string: "https://api.cloudflare.com/client/v4")!,
        session: URLSession = .shared,
        tokenProvider: @escaping () throws -> String
    ) {
        self.baseURL       = baseURL
        self.session       = session
        self.tokenProvider = tokenProvider
    }

    // MARK: - List

    func listDNSRecords(zoneID: String, type: DNSRecordType? = nil, name: String? = nil) async throws -> [DNSRecord] {
        var components = URLComponents(url: baseURL.appendingPathComponent("zones/\(zoneID)/dns_records"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [URLQueryItem(name: "per_page", value: "100")]
        if let type  { items.append(URLQueryItem(name: "type", value: type.rawValue)) }
        if let name  { items.append(URLQueryItem(name: "name", value: name)) }
        components.queryItems = items

        let request = try authorisedRequest(url: components.url!)
        let envelope: DNSRecordListResponse = try await perform(request)
        return envelope.result
    }

    // MARK: - Get

    func getDNSRecord(zoneID: String, recordID: String) async throws -> DNSRecord {
        let url = baseURL.appendingPathComponent("zones/\(zoneID)/dns_records/\(recordID)")
        let request = try authorisedRequest(url: url)
        let envelope: CloudflareAPIEnvelope<DNSRecord> = try await perform(request)
        return envelope.result
    }

    // MARK: - Create

    func createDNSRecord(zoneID: String, request body: CreateDNSRecordRequest) async throws -> DNSRecord {
        let url = baseURL.appendingPathComponent("zones/\(zoneID)/dns_records")
        var request = try authorisedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.cloudflare.encode(body)
        let envelope: CloudflareAPIEnvelope<DNSRecord> = try await perform(request)
        return envelope.result
    }

    // MARK: - Update

    func updateDNSRecord(zoneID: String, recordID: String, request body: UpdateDNSRecordRequest) async throws -> DNSRecord {
        let url = baseURL.appendingPathComponent("zones/\(zoneID)/dns_records/\(recordID)")
        var request = try authorisedRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.cloudflare.encode(body)
        let envelope: CloudflareAPIEnvelope<DNSRecord> = try await perform(request)
        return envelope.result
    }

    // MARK: - Delete

    func deleteDNSRecord(zoneID: String, recordID: String) async throws {
        let url = baseURL.appendingPathComponent("zones/\(zoneID)/dns_records/\(recordID)")
        var request = try authorisedRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }

    // MARK: - Private helpers

    private func authorisedRequest(url: URL) throws -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue("Bearer \(try tokenProvider())", forHTTPHeaderField: "Authorization")
        return r
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try JSONDecoder.cloudflare.decode(T.self, from: data)
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 401:       throw TunnelError.unauthorized
        case 403:       throw TunnelError.forbidden
        case 404:       throw TunnelError.tunnelNotFound
        case 429:
            let retryAfter = (response as? HTTPURLResponse)
                .flatMap { $0.value(forHTTPHeaderField: "Retry-After") }
                .flatMap { TimeInterval($0) }
            throw TunnelError.rateLimited(retryAfter: retryAfter)
        case 500...599: throw TunnelError.serverUnavailable
        default:        throw TunnelError.unknown(message: "HTTP \(http.statusCode)")
        }
    }
}
