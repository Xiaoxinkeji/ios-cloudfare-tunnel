// Core/Notifications/TunnelNotificationState.swift
import Foundation
import UserNotifications

// MARK: - Notification Events

enum LocalNotificationEvent: String, CaseIterable {
    case tunnelDown      = "tunnel.down"
    case tunnelDegraded  = "tunnel.degraded"
    case tokenInvalid    = "auth.token_invalid"
    case backendUnreachable = "auth.backend_unreachable"
}

// MARK: - Per-Tunnel Notification State

/// Persisted per-tunnel state used for edge-detection and dedup.
struct TunnelNotificationState: Equatable, Codable {
    let tunnelID: String
    var lastKnownStatus: String?
    var lastConnectionCount: Int
    var lastDownNotifiedAt: Date?
    var lastDegradedNotifiedAt: Date?
    var lastTokenInvalidNotifiedAt: Date?
    /// Consecutive poll failures (used to avoid single-sample false positives).
    var consecutiveEmptyConnectionCount: Int

    init(tunnelID: String) {
        self.tunnelID                    = tunnelID
        self.lastKnownStatus             = nil
        self.lastConnectionCount         = 0
        self.lastDownNotifiedAt          = nil
        self.lastDegradedNotifiedAt      = nil
        self.lastTokenInvalidNotifiedAt  = nil
        self.consecutiveEmptyConnectionCount = 0
    }
}

// MARK: - Notification Evaluator

/// Stateless function: given previous state and current observations, returns which
/// events should be fired.  Caller is responsible for persisting the updated state.
func evaluateNotifications(
    previous: TunnelNotificationState?,
    tunnelName: String,
    tunnelID: String,
    currentStatus: String,
    connectionCount: Int,
    authError: TunnelError?,
    now: Date = .now
) -> (events: [LocalNotificationEvent], updatedState: TunnelNotificationState) {

    var state = previous ?? TunnelNotificationState(tunnelID: tunnelID)
    var events: [LocalNotificationEvent] = []

    // ── Auth error ────────────────────────────────────────────────────────
    if let authError {
        let isAuthFailure: Bool
        switch authError {
        case .unauthorized, .forbidden: isAuthFailure = true
        default:                        isAuthFailure = false
        }

        if isAuthFailure {
            let cooldown: TimeInterval = 30 * 60   // 30 min
            let lastFired = state.lastTokenInvalidNotifiedAt ?? .distantPast
            if now.timeIntervalSince(lastFired) >= cooldown {
                events.append(.tokenInvalid)
                state.lastTokenInvalidNotifiedAt = now
            }
        }
    }

    // ── Tunnel status transitions ─────────────────────────────────────────
    let prevStatus = state.lastKnownStatus ?? "unknown"
    let cooldown30min: TimeInterval = 30 * 60

    // Track consecutive empty connections for "down" detection
    if connectionCount == 0 {
        state.consecutiveEmptyConnectionCount += 1
    } else {
        state.consecutiveEmptyConnectionCount = 0
    }

    let effectivelyDown = currentStatus == "down"
        || (connectionCount == 0 && state.consecutiveEmptyConnectionCount >= 2)

    if (prevStatus == "healthy" || prevStatus == "degraded") && effectivelyDown {
        let lastFired = state.lastDownNotifiedAt ?? .distantPast
        if now.timeIntervalSince(lastFired) >= cooldown30min {
            events.append(.tunnelDown)
            state.lastDownNotifiedAt = now
        }
    }

    if prevStatus == "healthy" && currentStatus == "degraded" {
        let lastFired = state.lastDegradedNotifiedAt ?? .distantPast
        if now.timeIntervalSince(lastFired) >= cooldown30min {
            events.append(.tunnelDegraded)
            state.lastDegradedNotifiedAt = now
        }
    }

    state.lastKnownStatus    = currentStatus
    state.lastConnectionCount = connectionCount

    return (events, state)
}

// MARK: - Notification Scheduler

@MainActor
final class TunnelNotificationScheduler {

    static let shared = TunnelNotificationScheduler()
    private init() {}

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    func schedule(event: LocalNotificationEvent, tunnelName: String) {
        let content = UNMutableNotificationContent()
        switch event {
        case .tunnelDown:
            content.title = "Tunnel 已离线"
            content.body  = "\(tunnelName) 当前无法连接到 Cloudflare Edge。"
            content.sound = .default
        case .tunnelDegraded:
            content.title = "Tunnel 状态降级"
            content.body  = "\(tunnelName) 仍可提供服务，但健康状态异常。"
            content.sound = .default
        case .tokenInvalid:
            content.title = "Cloudflare 凭证失效"
            content.body  = "请重新检查 API Token 或权限范围。"
            content.sound = .defaultCritical
        case .backendUnreachable:
            content.title = "控制后端认证失效"
            content.body  = "请重新登录或更新控制后端凭证。"
            content.sound = .default
        }

        let id = "\(event.rawValue).\(tunnelName)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleAll(events: [LocalNotificationEvent], tunnelName: String) {
        for event in events {
            schedule(event: event, tunnelName: tunnelName)
        }
    }
}
