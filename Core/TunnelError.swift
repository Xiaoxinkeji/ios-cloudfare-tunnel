// Core/TunnelError.swift
// Cloudflare Tunnel – typed error domain

import Foundation

enum TunnelError: Error, Equatable {
    case invalidConfiguration
    case unauthorized
    case timeout
    case decoding
    case api(String)
    case transport(String)

    // MARK: - Human-readable descriptions

    var localizedDescription: String {
        switch self {
        case .invalidConfiguration:
            return "The tunnel configuration is incomplete or invalid. Please check your API Token, Tunnel ID, and Account ID in Settings."
        case .unauthorized:
            return "Authentication failed. Your API Token may be missing or expired. Please update it in Settings."
        case .timeout:
            return "The request timed out. Please check your internet connection and try again."
        case .decoding:
            return "An unexpected response was received from the Cloudflare API. Please try again later."
        case .api(let message):
            return "Cloudflare API error: \(message)"
        case .transport(let message):
            return "Network error: \(message)"
        }
    }
}
