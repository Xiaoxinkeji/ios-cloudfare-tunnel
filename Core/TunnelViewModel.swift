// Core/TunnelViewModel.swift
// Observable view-model that drives the entire app UI

import Foundation
import SwiftUI
import Combine

@MainActor
final class TunnelViewModel: ObservableObject {

    // MARK: - Published state

    @Published var state: TunnelState = .disconnected
    @Published var lastRefreshed: Date? = nil
    @Published var config: TunnelConfig = Storage.loadConfig() ?? .default

    // MARK: - Private

    private var apiClient: CloudflareTunnelAPIProtocol
    private var pollingTask: Task<Void, Never>?
    private let pollingInterval: TimeInterval = 30

    // MARK: - Init

    init() {
        self.apiClient = RemoteCloudflareAPIClient(config: Storage.loadConfig() ?? .default)
    }

    // MARK: - Derived UI properties

    /// Which actions are currently available given the current state.
    var availableActions: [TunnelAction] {
        state.validActions
    }

    /// Label shown on the single primary action button.
    var primaryButtonLabel: String {
        switch state {
        case .disconnected:             return "Connect"
        case .connecting:               return "Connecting…"
        case .connected:                return "Disconnect"
        case .disconnecting:            return "Disconnecting…"
        case .failure:                  return "Retry"
        }
    }

    /// Text and tint colour for the status indicator.
    var statusDisplay: (text: String, tint: Color) {
        switch state {
        case .disconnected:
            return ("Disconnected", .gray)
        case .connecting:
            return ("Connecting", .orange)
        case .connected(let info):
            return ("Connected – \(info.name)", .green)
        case .disconnecting:
            return ("Disconnecting", .orange)
        case .failure:
            return ("Connection Failed", .red)
        }
    }

    /// The tunnel display name shown at the top of HomeView.
    var tunnelDisplayName: String {
        if case .connected(let info) = state, !info.name.isEmpty {
            return info.name
        }
        return config.tunnelId.isEmpty ? "My Tunnel" : config.tunnelId
    }

    /// Error message string when state == .failure, otherwise nil.
    var errorMessage: String? {
        if case .failure(let error) = state {
            return error.localizedDescription
        }
        return nil
    }

    // MARK: - Actions

    /// Dispatches a `TunnelAction`, runs the appropriate API call, and updates `state`.
    func perform(_ action: TunnelAction) async {
        guard !config.tunnelId.isEmpty, !config.accountId.isEmpty else {
            state = .failure(error: .invalidConfiguration)
            return
        }

        switch action {

        case .start:
            state = .connecting
            do {
                let info = try await apiClient.startTunnel(id: config.tunnelId)
                state = .connected(info: info)
                lastRefreshed = Date()
            } catch let error as TunnelError {
                state = .failure(error: error)
            } catch {
                state = .failure(error: .transport(error.localizedDescription))
            }

        case .stop:
            state = .disconnecting
            do {
                let info = try await apiClient.stopTunnel(id: config.tunnelId)
                // After DELETE the tunnel may still report a status; treat non-healthy as disconnected.
                if info.isRunning {
                    state = .connected(info: info)
                } else {
                    state = .disconnected
                }
                lastRefreshed = Date()
            } catch let error as TunnelError {
                state = .failure(error: error)
            } catch {
                state = .failure(error: .transport(error.localizedDescription))
            }

        case .refresh:
            do {
                let info = try await apiClient.getTunnelStatus(id: config.tunnelId)
                state = info.isRunning ? .connected(info: info) : .disconnected
                lastRefreshed = Date()
            } catch let error as TunnelError {
                state = .failure(error: error)
            } catch {
                state = .failure(error: .transport(error.localizedDescription))
            }

        case .retry:
            // Retry goes back to disconnected then immediately starts.
            state = .disconnected
            await perform(.start)
        }
    }

    // MARK: - Polling

    /// Starts a repeating 30-second status-refresh loop.
    func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(30 * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self?.perform(.refresh)
            }
        }
    }

    /// Cancels the polling loop.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Config persistence

    /// Persists the current `config` to UserDefaults and rebuilds the API client.
    func saveConfig() {
        Storage.saveConfig(config)
        apiClient = RemoteCloudflareAPIClient(config: config)
    }

    /// Re-loads config from UserDefaults (called after ConfigEditorView saves).
    func reloadConfig() {
        if let saved = Storage.loadConfig() {
            config = saved
        }
        apiClient = RemoteCloudflareAPIClient(config: config)
    }
}
