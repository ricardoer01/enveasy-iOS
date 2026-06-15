//
//  TokenStorage.swift
//  inveasy
//

import Foundation

struct TokenPair: Equatable {
    let accessToken: String
    let refreshToken: String
}

/// Persists the access + refresh token pair in the Keychain.
///
/// The Inveasy API rotates BOTH tokens on every successful `/auth/refresh`.
/// Always call `save(_:)` with the new pair returned by the server; never
/// store tokens partially.
struct TokenStorage {
    private let keychain: Keychain
    private let accessAccount = "auth.access_token"
    private let refreshAccount = "auth.refresh_token"

    init(keychain: Keychain = Keychain()) {
        self.keychain = keychain
    }

    func load() throws -> TokenPair? {
        let access = try keychain.string(for: accessAccount)
        let refresh = try keychain.string(for: refreshAccount)
        guard let access, let refresh else { return nil }
        return TokenPair(accessToken: access, refreshToken: refresh)
    }

    func save(_ pair: TokenPair) throws {
        try keychain.setString(pair.accessToken, for: accessAccount)
        try keychain.setString(pair.refreshToken, for: refreshAccount)
    }

    func clear() throws {
        try keychain.remove(accessAccount)
        try keychain.remove(refreshAccount)
    }
}
