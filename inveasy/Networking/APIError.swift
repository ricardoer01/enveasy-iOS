//
//  APIError.swift
//  inveasy
//

import Foundation

/// Errors surfaced by `APIClient`.
///
/// The Inveasy backend always returns `{ "error": "..." }` for failures, and
/// validation failures (HTTP 422) add a `details` map of field → messages.
enum APIError: Error, Equatable {
    /// 422 — request body failed validation.
    case validation(message: String, details: [String: [String]])
    /// 401 — credentials were rejected (e.g. wrong password) or the refresh
    /// token has expired/been revoked. Caller should send the user to login.
    case unauthorized(message: String)
    /// 404 — resource not found, or not visible to the caller.
    case notFound(message: String)
    /// 409 — conflict (e.g. cancelling an order that's already shipped).
    case conflict(message: String)
    /// Any other non-2xx HTTP status.
    case server(status: Int, message: String)
    /// Network or transport failure (no usable HTTP response).
    case transport(message: String)
    /// Response body could not be decoded into the expected type.
    case decoding(message: String)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .validation(let message, _),
             .unauthorized(let message),
             .notFound(let message),
             .conflict(let message),
             .server(_, let message),
             .transport(let message),
             .decoding(let message):
            return message
        }
    }
}

/// Wire shape for the standard error body.
struct APIErrorBody: Decodable {
    let error: String
    let details: [String: [String]]?
}
