// Core/UIHelpers.swift
// Lightweight UI extensions shared across views.

import SwiftUI

// MARK: - TunnelState UI

extension TunnelState {
    /// Color used to render a status indicator for the current state.
    var tint: Color {
        switch self {
        case .disconnected:                return .gray
        case .connecting, .disconnecting:  return .orange
        case .connected:                   return .green
        case .failure:                     return .red
        }
    }
}

// MARK: - AuthState UI

extension AuthState {
    /// Short, user-facing description of the auth status.
    var title: String {
        switch self {
        case .unconfigured:           return "Not configured"
        case .ready:                  return "Ready"
        case .invalid(let reason):    return "Invalid: \(reason)"
        }
    }
}
