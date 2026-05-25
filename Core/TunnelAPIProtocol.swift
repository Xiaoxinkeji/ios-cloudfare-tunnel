// Core/TunnelAPIProtocol.swift
import Foundation

protocol CloudflareTunnelAPIProtocol {
    func fetchTunnelDetail(accountId: String, tunnelId: String) async throws -> CloudflareTunnel
    func fetchConnections(accountId: String, tunnelId: String) async throws -> [TunnelConnectionClient]
    func fetchToken(accountId: String, tunnelId: String) async throws -> String
    func updateConfiguration(accountId: String, tunnelId: String, config: TunnelRemoteConfig) async throws
    func saveConfiguration(_ configuration: TunnelConfiguration) async throws
    func authState() async -> AuthState
}

protocol TunnelControlBackendAPIProtocol {
    func startTunnel(tunnelId: String) async throws -> RuntimeTunnelStatus
    func stopTunnel(tunnelId: String) async throws -> RuntimeTunnelStatus
    func fetchRuntimeStatus(tunnelId: String) async throws -> RuntimeTunnelStatus
    func authState() async -> AuthState
}
