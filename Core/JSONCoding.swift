// Core/JSONCoding.swift
// Shared JSON encoder / decoder with Cloudflare-compatible settings

import Foundation

extension JSONDecoder {
    /// Shared decoder pre-configured for Cloudflare API responses.
    ///
    /// - Key strategy : `convertFromSnakeCase`  (maps `created_at` → `createdAt`)
    /// - Date strategy: `iso8601`               (parses ISO-8601 timestamps)
    static let cloudflare: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy  = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    /// Shared encoder pre-configured to produce Cloudflare-compatible JSON.
    ///
    /// - Key strategy : `convertToSnakeCase`
    /// - Date strategy: `iso8601`
    static let cloudflare: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy  = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting     = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

// MARK: - Aliases used by the tunnel API / control-plane API layers
// These point at the same Cloudflare-compatible coders so that call sites
// using either name compile against a single shared configuration.

extension JSONDecoder {
    static let tunnelDecoder: JSONDecoder = JSONDecoder.cloudflare
}

extension JSONEncoder {
    static let tunnelEncoder: JSONEncoder = JSONEncoder.cloudflare
}
