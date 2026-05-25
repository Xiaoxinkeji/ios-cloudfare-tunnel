// Core/CloudflareAPI.swift
// Concrete Cloudflare Tunnel REST API client

import Foundation

// MARK: - RemoteCloudflareAPIClient

final class RemoteCloudflareAPIClient: CloudflareTunnelAPIProtocol {

    // MARK: - Properties

    private let config: TunnelConfig
    private let session: URLSession

    private var bearerToken: String {
        get throws {
            do {
                return try Storage.loadToken()
            } catch {
                throw TunnelError.invalidConfiguration(reason: "API Token 未设置或读取失败。")
            }
        }
    }

    // MARK: - Init

    init(config: TunnelConfig, session: URLSession = .shared) {
        self.config  = config
        self.session = session
    }

    // MARK: - CloudflareTunnelAPIProtocol

    func startTunnel(id: String) async throws -> TunnelInfo {
        // Cloudflare does not expose a "start connector" endpoint in the public v4 API;
        // the tunnel daemon itself initiates outbound connections.  The closest public
        // operation is clearing any forced-offline / clean-up state by issuing a PATCH
        // to the tunnel resource with `{"connections_limit": null}`.  We perform a
        // status fetch here and surface the result so the UI can show the current state.
        //
        // If your deployment uses a custom control-plane endpoint that does expose a
        // start verb, replace the body below with the appropriate POST call.
        let url = try buildURL(path: "/accounts/\(config.accountId)/cfd_tunnel/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try applyAuth(to: &request)

        // Send an empty PATCH body – Cloudflare accepts this and returns the tunnel record.
        request.httpBody = try JSONEncoder.cloudflare.encode(EmptyBody())

        return try await performRequest(request)
    }

    func stopTunnel(id: String) async throws -> TunnelInfo {
        // DELETE to the connections endpoint forces the tunnel into a disconnected state
        // (terminates active connections).
        let url = try buildURL(path: "/accounts/\(config.accountId)/cfd_tunnel/\(id)/connections")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try applyAuth(to: &request)

        // DELETE returns the tunnel object on success.
        return try await performRequest(request)
    }

    func getTunnelStatus(id: String) async throws -> TunnelInfo {
        let url = try buildURL(path: "/accounts/\(config.accountId)/cfd_tunnel/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try applyAuth(to: &request)

        return try await performRequest(request)
    }

    // MARK: - Private helpers

    private func buildURL(path: String) throws -> URL {
        guard
            !config.accountId.isEmpty,
            !config.baseURL.isEmpty,
            let base = URL(string: config.baseURL),
            let url  = URL(string: path, relativeTo: base)
        else {
            throw TunnelError.invalidConfiguration(reason: "Account ID 或 Base URL 无效。")
        }
        return url
    }

    private func applyAuth(to request: inout URLRequest) throws {
        let token = try bearerToken
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    /// Performs a request, decodes the Cloudflare envelope, and returns the inner result.
    @discardableResult
    private func performRequest(_ request: URLRequest) async throws -> TunnelInfo {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost:
                throw TunnelError.networkUnavailable
            case .notConnectedToInternet, .dataNotAllowed:
                throw TunnelError.networkUnavailable
            default:
                throw TunnelError.unknown(message: urlError.localizedDescription)
            }
        } catch {
            throw TunnelError.unknown(message: error.localizedDescription)
        }

        // Map HTTP status codes to typed errors before attempting decode.
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299:
                break // OK – fall through to decode

            case 401:
                throw TunnelError.unauthorized

            case 403:
                throw TunnelError.forbidden

            case 404:
                throw TunnelError.tunnelNotFound

            case 409:
                throw TunnelError.conflict

            case 429:
                // Honour Retry-After header when present.
                let retryAfter: TimeInterval?
                if let raw = httpResponse.value(forHTTPHeaderField: "Retry-After"),
                   let seconds = TimeInterval(raw) {
                    retryAfter = seconds
                } else {
                    retryAfter = nil
                }
                throw TunnelError.rateLimited(retryAfter: retryAfter)

            case 500...599:
                throw TunnelError.serverUnavailable

            default:
                // Try to extract Cloudflare error message from body.
                if let envelope = try? JSONDecoder.cloudflare.decode(
                    CloudflareResponse<AnyCodable>.self, from: data),
                   let firstError = envelope.errors.first {
                    throw TunnelError.unknown(message: "\(firstError.message) (code \(firstError.code))")
                }
                throw TunnelError.unknown(message: "HTTP \(httpResponse.statusCode)")
            }
        }

        // Decode the Cloudflare v4 envelope: { "result": {...}, "success": bool, "errors": [...] }
        do {
            let envelope = try JSONDecoder.cloudflare.decode(
                CloudflareResponse<TunnelInfo>.self, from: data
            )

            if !envelope.success {
                let message = envelope.errors.first.map {
                    "\($0.message) (code \($0.code))"
                } ?? "Unknown API error"
                throw TunnelError.unknown(message: message)
            }

            guard let tunnelInfo = envelope.result else {
                throw TunnelError.decodingFailed
            }

            return tunnelInfo
        } catch let tunnelErr as TunnelError {
            throw tunnelErr
        } catch {
            throw TunnelError.decodingFailed
        }
    }
}

// MARK: - Support types

/// Placeholder for requests that need an empty JSON body `{}`.
private struct EmptyBody: Encodable {}

/// Type-erased Decodable used when we only need the error envelope, not the result payload.
private struct AnyCodable: Decodable {}
