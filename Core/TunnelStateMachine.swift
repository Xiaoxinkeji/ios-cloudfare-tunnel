// Core/TunnelStateMachine.swift
// Finite-state machine types for the tunnel lifecycle

import Foundation

// MARK: - TunnelState

enum TunnelState: Equatable {
    case disconnected
    case connecting
    case connected(info: TunnelInfo)
    case disconnecting
    case failure(error: TunnelError)

    // Equatable for associated-value cases
    static func == (lhs: TunnelState, rhs: TunnelState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):           return true
        case (.connecting, .connecting):               return true
        case (.disconnecting, .disconnecting):         return true
        case (.connected(let a), .connected(let b)):   return a == b
        case (.failure(let a), .failure(let b)):       return a == b
        default:                                       return false
        }
    }
}

// MARK: - TunnelAction

enum TunnelAction {
    case start
    case stop
    case refresh
    case retry
}

// MARK: - State-machine transition logic

extension TunnelState {

    /// Returns the set of actions that are valid to dispatch from the current state.
    var validActions: [TunnelAction] {
        switch self {
        case .disconnected:
            return [.start]
        case .connecting:
            return []                // Busy – no user actions permitted
        case .connected:
            return [.stop, .refresh]
        case .disconnecting:
            return []                // Busy – no user actions permitted
        case .failure:
            return [.retry, .start]
        }
    }

    /// Whether a spinner / loading indicator should be shown.
    var isBusy: Bool {
        switch self {
        case .connecting, .disconnecting: return true
        default:                          return false
        }
    }
}
