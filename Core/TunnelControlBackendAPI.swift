// Core/TunnelControlBackendAPI.swift
import Foundation

final class TunnelControlBackendAPIClient: TunnelControlBackendAPIProtocol {
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
            let configuration = try configurationStore.load()
            switch configuration.controlPlaneAuthMode {
            case .none:
                return .ready
            case .bearerToken:
                let token = try credentialStore.loadControlPlaneBearerToken()
                return token?.isEmpty == false ? .ready : .unconfigured
            case .serviceToken:
                return try credentialStore.loadControlPlaneServiceToken() == nil ? .unconfigured : .ready
            }
        } catch {
            return .invalid(reason: error.localizedDescription)
        }
    }

    func startTunnel(tunnelId: String) async throws -> RuntimeTunnelStatus {
        try await request(path: "/api/tunnel/start", method: "POST", tunnelId: tunnelId)
    }

    func stopTunnel(tunnelId: String) async throws -> RuntimeTunnelStatus {
        try await request(path: "/api/tunnel/stop", method: "POST", tunnelId: tunnelId)
    }

    func fetchRuntimeStatus(tunnelId: String) async throws -> RuntimeTunnelStatus {
        try await request(path: "/api/tunnel/status", method: "GET", tunnelId: tunnelId)
    }

    private func request(path: String, method: String, tunnelId: String) async throws -> RuntimeTunnelStatus {
        let configuration = try configurationStore.load()
        guard let baseURL = configuration.controlPlaneURL else {
            throw TunnelError.invalidConfiguration(reason: "Control backend URL is missing.")
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(tunnelId, forHTTPHeaderField: "X-Tunnel-ID")
        try applyAuthentication(to: &request, mode: configuration.controlPlaneAuthMode)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TunnelError.unknown(message: "Control backend returned an invalid response.")
            }

            switch http.statusCode {
            case 200..<300:
                do {
                    return try JSONDecoder.tunnelDecoder.decode(RuntimeTunnelStatus.self, from: data)
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
                throw TunnelError.unknown(message: String(data: data, encoding: .utf8) ?? "Unknown backend error.")
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

    private func applyAuthentication(to request: inout URLRequest, mode: ControlPlaneAuthMode) throws {
        switch mode {
        case .none:
            return
        case .bearerToken:
            guard let token = try credentialStore.loadControlPlaneBearerToken(), !token.isEmpty else {
                throw TunnelError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .serviceToken:
            guard let token = try credentialStore.loadControlPlaneServiceToken() else {
                throw TunnelError.unauthorized
            }
            request.setValue(token.clientId, forHTTPHeaderField: "CF-Access-Client-Id")
            request.setValue(token.clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
    }
}
