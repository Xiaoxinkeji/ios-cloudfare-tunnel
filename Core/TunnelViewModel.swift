// Core/TunnelViewModel.swift
import Foundation
import SwiftUI

@MainActor
final class TunnelViewModel: ObservableObject {
    @Published var status: TunnelStatus = .idle
    @Published var configuration: TunnelConfiguration = .defaultValue
    @Published var transientError: TunnelError?
    @Published var isEditingConfig = false
    @Published private(set) var cloudflareAuthState: AuthState = .unconfigured
    @Published private(set) var controlPlaneAuthState: AuthState = .unconfigured

    private let cloudflareAPI: CloudflareTunnelAPIProtocol
    private let controlBackendAPI: TunnelControlBackendAPIProtocol
    private var didLoad = false

    init(
        cloudflareAPI: CloudflareTunnelAPIProtocol = CloudflareTunnelAPIClient(),
        controlBackendAPI: TunnelControlBackendAPIProtocol = TunnelControlBackendAPIClient()
    ) {
        self.cloudflareAPI = cloudflareAPI
        self.controlBackendAPI = controlBackendAPI

        do {
            configuration = try TunnelConfigurationStore.shared.load()
        } catch {
            transientError = .invalidConfiguration(reason: error.localizedDescription)
        }
    }

    var isBusy: Bool { status.state.isBusy }

    var primaryActionTitle: String {
        switch status.state {
        case .disconnected: return "Start Tunnel"
        case .connecting: return "Connecting…"
        case .connected: return "Stop Tunnel"
        case .disconnecting: return "Stopping…"
        case .failure: return "Retry"
        }
    }

    var primaryActionColor: Color {
        switch status.state {
        case .connected: return .red
        case .connecting, .disconnecting: return .orange
        case .disconnected, .failure: return .blue
        }
    }

    var lastUpdatedText: String {
        guard let lastUpdatedAt = status.lastUpdatedAt else { return "Never updated" }
        return lastUpdatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refreshAuthState()
        await refresh()
    }

    func primaryAction() async {
        switch status.state {
        case .disconnected: await perform(.start)
        case .connected: await perform(.stop)
        case .failure: await perform(.retry)
        case .connecting, .disconnecting: break
        }
    }

    func perform(_ action: TunnelAction) async {
        switch (status.state, action) {
        case (.disconnected, .start):
            status = .connecting(message: "Sending start request…", updatedAt: Date())
            await startTunnel()
        case (.connected, .stop):
            status = .disconnecting(message: "Sending stop request…", updatedAt: Date())
            await stopTunnel()
        case (_, .refresh):
            await refresh()
        case (.failure, .retry):
            transientError = nil
            status = .disconnected(message: "Ready to retry.", updatedAt: Date())
        default:
            break
        }
    }

    func refresh() async {
        do {
            let tunnelId = try requireTunnelID()
            let accountId = try requireAccountID()

            async let tunnel = cloudflareAPI.fetchTunnelDetail(accountId: accountId, tunnelId: tunnelId)
            async let connections = cloudflareAPI.fetchConnections(accountId: accountId, tunnelId: tunnelId)
            async let runtime = controlBackendAPI.fetchRuntimeStatus(tunnelId: tunnelId)

            let (loadedTunnel, loadedConnections, runtimeStatus) = try await (tunnel, connections, runtime)
            status = mapStatus(runtime: runtimeStatus, tunnel: loadedTunnel, connections: loadedConnections)
            transientError = nil
        } catch let error as TunnelError {
            if case .connected = status.state {
                transientError = error
            } else {
                status = .failure(message: error.message, updatedAt: Date())
                transientError = error
            }
        } catch {
            let tunnelError = TunnelError.unknown(message: error.localizedDescription)
            status = .failure(message: tunnelError.message, updatedAt: Date())
            transientError = tunnelError
        }

        await refreshAuthState()
    }

    func saveConfiguration(_ configuration: TunnelConfiguration) async {
        do {
            try await cloudflareAPI.saveConfiguration(configuration)
            self.configuration = configuration
            transientError = nil
            await refreshAuthState()
            await refresh()
        } catch let error as TunnelError {
            status = .failure(message: error.message, updatedAt: Date())
            transientError = error
        } catch {
            let tunnelError = TunnelError.unknown(message: error.localizedDescription)
            status = .failure(message: tunnelError.message, updatedAt: Date())
            transientError = tunnelError
        }
    }

    private func startTunnel() async {
        await runControlAction(maxRetries: 2, delays: [1, 2]) { [self] in
            try await controlBackendAPI.startTunnel(tunnelId: requireTunnelID())
        }
    }

    private func stopTunnel() async {
        await runControlAction(maxRetries: 2, delays: [1, 2]) { [self] in
            try await controlBackendAPI.stopTunnel(tunnelId: requireTunnelID())
        }
    }

    private func runControlAction(
        maxRetries: Int,
        delays: [TimeInterval],
        operation: @escaping () async throws -> RuntimeTunnelStatus
    ) async {
        var attempt = 0

        while true {
            do {
                let runtime = try await operation()
                let tunnelId = try requireTunnelID()
                let accountId = try requireAccountID()
                let tunnel = try await cloudflareAPI.fetchTunnelDetail(accountId: accountId, tunnelId: tunnelId)
                let connections = try await cloudflareAPI.fetchConnections(accountId: accountId, tunnelId: tunnelId)

                status = mapStatus(runtime: runtime, tunnel: tunnel, connections: connections)
                transientError = nil
                return
            } catch let error as TunnelError {
                if error.shouldAutoRetry && attempt < maxRetries {
                    let delay = attempt < delays.count ? delays[attempt] : error.suggestedRetryDelay
                    attempt += 1
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                status = .failure(message: error.message, updatedAt: Date())
                transientError = error
                return
            } catch {
                let tunnelError = TunnelError.unknown(message: error.localizedDescription)
                status = .failure(message: tunnelError.message, updatedAt: Date())
                transientError = tunnelError
                return
            }
        }
    }

    private func mapStatus(
        runtime: RuntimeTunnelStatus,
        tunnel: CloudflareTunnel,
        connections: [TunnelConnectionClient]
    ) -> TunnelStatus {
        let info = TunnelInfo(
            id: tunnel.id,
            name: tunnel.name,
            status: tunnel.status ?? "unknown",
            createdAt: tunnel.createdAt,
            healthcheck: nil,
            healthSummary: runtime.healthcheck,
            logLines: (runtime.logs ?? []).map { TunnelLogEntry(timestamp: Date(), message: $0) }
        )

        switch runtime.state {
        case .disconnected:
            return .disconnected(message: runtime.subtitle, updatedAt: runtime.updatedAt)
        case .connecting:
            return .connecting(message: runtime.subtitle, updatedAt: runtime.updatedAt)
        case .connected:
            return .connected(
                info: info,
                title: runtime.title,
                subtitle: runtime.subtitle,
                updatedAt: runtime.updatedAt,
                healthSummary: tunnel.status ?? runtime.healthcheck ?? "healthy",
                logLines: runtime.logs ?? [],
                tunnel: tunnel,
                connections: connections
            )
        case .disconnecting:
            return .disconnecting(message: runtime.subtitle, updatedAt: runtime.updatedAt)
        case .failure:
            return .failure(message: runtime.subtitle, updatedAt: runtime.updatedAt)
        }
    }

    private func refreshAuthState() async {
        cloudflareAuthState = await cloudflareAPI.authState()
        controlPlaneAuthState = await controlBackendAPI.authState()
    }

    private func requireTunnelID() throws -> String {
        guard let tunnelId = configuration.tunnelId?.trimmingCharacters(in: .whitespacesAndNewlines), !tunnelId.isEmpty else {
            throw TunnelError.invalidConfiguration(reason: "Tunnel ID is missing.")
        }
        return tunnelId
    }

    private func requireAccountID() throws -> String {
        let accountId = configuration.accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountId.isEmpty else {
            throw TunnelError.invalidConfiguration(reason: "Account ID is missing.")
        }
        return accountId
    }
}
