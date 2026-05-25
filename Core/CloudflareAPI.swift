// Core/CloudflareAPI.swift
import Foundation

final class CloudflareTunnelAPIClient: CloudflareTunnelAPIProtocol {
    private let session: URLSession
    private let credentialStore: TunnelCredentialStore
    private let configurationStore: TunnelConfigurationStore

    init(
        session: URLSession = .shared,
        credentialStore: TunnelCredentialStore = .shared,
        configurationStore: TunnelConfigurationStore = .shared
    ) {
        self.session = session
        self.credentialStore = credentialStore
        self.configurationStore = configurationStore
    }

    func authState() async -> AuthState {
        do {
            if try credentialStore.loadCloudflareCredentials() != nil {
                return .ready
            }
            return .unconfigured
        } catch {
            return .invalid(reason: error.localizedDescription)
        }
    }

    func fetchTunnelDetail(accountId: String, tunnelId: String) async throws -> CloudflareTunnel {
        let path = "/client/v4/accounts/\(accountId)/cfd_tunnel/\(tunnelId)"
        let envelope: APIEnvelope<CloudflareTunnel> = try await request(path: path, method: "GET", body: Optional<EmptyBody>.none)
        return envelope.result
    }

    func fetchConnections(accountId: String, tunnelId: String) async throws -> [TunnelConnectionClient] {
        let path = "/client/v4/accounts/\(accountId)/cfd_tunnel/\(tunnelId)/connections"
        let envelope: APIEnvelope<[TunnelConnectionClient]> = try await request(path: path, method: "GET", body: Optional<EmptyBody>.none)
        return envelope.result
    }

    func fetchToken(accountId: String, tunnelId: String) async throws -> String {
        let path = "/client/v4/accounts/\(accountId)/cfd_tunnel/\(tunnelId)/token"
        let envelope: APIEnvelope<String> = try await request(path: path, method: "GET", body: Optional<EmptyBody>.none)
        return envelope.result
    }

    func updateConfiguration(accountId: String, tunnelId: String, config: TunnelRemoteConfig) async throws {
        let path = "/client/v4/accounts/\(accountId)/cfd_tunnel/\(tunnelId)/configurations"
        let _: APIEnvelope<CloudflareTunnel> = try await request(path: path, method: "PUT", body: config)
    }

    func saveConfiguration(_ configuration: TunnelConfiguration) async throws {
        try configurationStore.save(configuration)
    }

    private struct EmptyBody: Encodable {}

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> T {
        guard let credentials = try credentialStore.loadCloudflareCredentials() else {
            throw TunnelError.unauthorized
        }

        let configuration = try configurationStore.load()
        var request = URLRequest(url: configuration.cloudflareAPIBaseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(credentials.apiToken)", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.tunnelEncoder.encode(body)
        }

        return try await execute(request)
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TunnelError.unknown(message: "Server returned an invalid response.")
            }

            switch http.statusCode {
            case 200..<300:
                do {
                    return try JSONDecoder.tunnelDecoder.decode(T.self, from: data)
                } catch {
                    throw TunnelError.decodingFailed
                }
            case 401:
                throw TunnelError.unauthorized
            case 403:
                throw TunnelError.forbidden
            case 404:
                throw TunnelError.tunnelNotFound
            case 409:
                throw TunnelError.conflict
            case 429:
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                throw TunnelError.rateLimited(retryAfter: retryAfter)
            case 500...599:
                throw TunnelError.serverUnavailable
            default:
                throw TunnelError.unknown(message: String(data: data, encoding: .utf8) ?? "Unknown API error.")
            }
        } catch let error as TunnelError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut, .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                throw TunnelError.networkUnavailable
            default:
                throw TunnelError.unknown(message: error.localizedDescription)
            }
        } catch {
            throw TunnelError.unknown(message: error.localizedDescription)
        }
    }
}

// Backwards-compat alias used by older call sites
typealias RemoteCloudflareAPIClient = CloudflareTunnelAPIClient
