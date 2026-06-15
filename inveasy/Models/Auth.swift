//
//  Auth.swift
//  inveasy
//

import Foundation

struct Customer: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let email: String
    let phone: String?
}

/// Returned by `/auth/login` and `/auth/register`.
struct AuthSession: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let customer: Customer
}

struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable, Sendable {
    let name: String
    let email: String
    let password: String
    let phone: String
}

struct RefreshRequest: Encodable, Sendable {
    let refreshToken: String
}

struct LogoutRequest: Encodable, Sendable {
    let refreshToken: String
}
