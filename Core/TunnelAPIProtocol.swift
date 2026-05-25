// Core/TunnelAPIProtocol.swift
// Abstraction over the Cloudflare Tunnel REST API

import Foundation

/// Conforming types can start, stop, and query the live state of a Cloudflare Tunnel.
///
/// All methods are `async throws` and deliver a fully-decoded `TunnelInfo` on success,
/// or throw a typed `TunnelError` on failure.
protocol CloudflareTunnelAPIProtocol {

    /// Instructs Cloudflare to bring the tunnel online.
    /// - Parameter id: The tunnel UUID, e.g. `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"`.
    /// - Returns: The latest `TunnelInfo` after the start request is accepted.
    func startTunnel(id: String) async throws -> TunnelInfo

    /// Instructs Cloudflare to take the tunnel offline.
    /// - Parameter id: The tunnel UUID.
    /// - Returns: The latest `TunnelInfo` after the stop request is accepted.
    func stopTunnel(id: String) async throws -> TunnelInfo

    /// Fetches the current status of the tunnel without changing its state.
    /// - Parameter id: The tunnel UUID.
    /// - Returns: The current `TunnelInfo` as reported by the Cloudflare API.
    func getTunnelStatus(id: String) async throws -> TunnelInfo
}
