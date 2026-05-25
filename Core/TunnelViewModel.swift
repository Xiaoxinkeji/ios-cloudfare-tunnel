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

    /// Non-blocking error shown as a transient banner (polling failures, conflict, etc.).
    /// Does NOT move the main `state` to `.failure`.
    @Published var transientError: TunnelError? = nil

    // MARK: - Private

    private var apiClient: CloudflareTunnelAPIProtocol
    private var pollingTask: Task<Void, Never>?
    private var transientErrorDismissTask: Task<Void, Never>?
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
            return error.message
        }
        return nil
    }

    // MARK: - Actions

    /// Dispatches a `TunnelAction`, runs the appropriate API call, and updates `state`.
    func perform(_ action: TunnelAction) async {
        guard !config.tunnelId.isEmpty, !config.accountId.isEmpty else {
            state = .failure(error: .invalidConfiguration(reason: "Tunnel ID 或 Account ID 未填写。"))
            return
        }

        switch action {

        case .start:
            state = .connecting
            await withExponentialBackoff(maxRetries: 2) {
                let info = try await self.apiClient.startTunnel(id: self.config.tunnelId)
                self.state = .connected(info: info)
                self.lastRefreshed = Date()
            } onFailure: { error in
                self.state = .failure(error: error)
            }

        case .stop:
            state = .disconnecting
            await withExponentialBackoff(maxRetries: 2) {
                let info = try await self.apiClient.stopTunnel(id: self.config.tunnelId)
                // After DELETE the tunnel may still report a status; treat non-healthy as disconnected.
                if info.isRunning {
                    self.state = .connected(info: info)
                } else {
                    self.state = .disconnected
                }
                self.lastRefreshed = Date()
            } onFailure: { error in
                self.state = .failure(error: error)
            }

        case .refresh:
            // Polling refresh: keep last connected state on error, surface via transientError.
            do {
                let info = try await apiClient.getTunnelStatus(id: config.tunnelId)
                state = info.isRunning ? .connected(info: info) : .disconnected
                lastRefreshed = Date()
                clearTransientError()
            } catch let error as TunnelError {
                postTransientError(error)
            } catch {
                postTransientError(.unknown(message: error.localizedDescription))
            }

        case .retry:
            // Retry goes back to disconnected then immediately starts.
            state = .disconnected
            await perform(.start)
        }
    }

    // MARK: - Transient error management

    /// Sets `transientError` and schedules an auto-dismiss after 3 seconds.
    private func postTransientError(_ error: TunnelError) {
        transientError = error
        transientErrorDismissTask?.cancel()
        transientErrorDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.transientError = nil }
        }
    }

    /// Clears any pending transient error immediately.
    private func clearTransientError() {
        transientErrorDismissTask?.cancel()
        transientErrorDismissTask = nil
        transientError = nil
    }

    // MARK: - Exponential backoff

    /// Runs `work` up to `1 + maxRetries` times, doubling the delay after each
    /// retryable failure.  Only retries when `TunnelError.shouldAutoRetry == true`.
    private func withExponentialBackoff(
        maxRetries: Int,
        work: @escaping () async throws -> Void,
        onFailure: @escaping (TunnelError) -> Void
    ) async {
        var attempt = 0
        var delay: TimeInterval = 1

        while true {
            do {
                try await work()
                return
            } catch let tunnelError as TunnelError {
                if tunnelError.shouldAutoRetry && attempt < maxRetries {
                    attempt += 1
                    let actualDelay = tunnelError.suggestedRetryDelay > 0
                        ? tunnelError.suggestedRetryDelay
                        : delay
                    try? await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
                    delay *= 2
                } else {
                    onFailure(tunnelError)
                    return
                }
            } catch {
                onFailure(.unknown(message: error.localizedDescription))
                return
            }
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
