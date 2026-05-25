// Core/AuthModels.swift
import Foundation

enum CloudflareManagementAuthMode: String, Codable, CaseIterable, Equatable {
    case apiToken
}

enum ControlPlaneAuthMode: String, Codable, CaseIterable, Equatable {
    case none
    case bearerToken
    case serviceToken
}

enum AuthState: Equatable {
    case unconfigured
    case ready
    case invalid(reason: String)
}

struct CloudflareManagementCredentials: Equatable {
    let apiToken: String
}

struct ControlPlaneServiceToken: Equatable {
    let clientId: String
    let clientSecret: String
}

struct ControlPlaneCredentials: Equatable {
    var bearerToken: String?
    var serviceToken: ControlPlaneServiceToken?

    static let empty = ControlPlaneCredentials(bearerToken: nil, serviceToken: nil)
}
