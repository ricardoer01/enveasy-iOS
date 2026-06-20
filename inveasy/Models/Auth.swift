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

/// Returned by `/auth/login` and `/auth/verify-email`.
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

/// `/auth/register` no longer returns tokens directly. It creates a customer
/// in `pending_verification` and the client must follow up with
/// `/auth/verify-email` once the user has entered the 6-digit code that was
/// sent to their inbox.
struct RegisterResponse: Decodable, Sendable {
    let status: String
    let customerId: UUID
}

struct VerifyEmailRequest: Encodable, Sendable {
    let customerId: UUID
    let code: String
}

struct RefreshRequest: Encodable, Sendable {
    let refreshToken: String
}

struct LogoutRequest: Encodable, Sendable {
    let refreshToken: String
}
