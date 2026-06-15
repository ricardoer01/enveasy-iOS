//
//  Endpoint.swift
//  inveasy
//

import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Which base URL an endpoint resolves against.
///
/// - `hub`: the fixed hub (`AppConfig.hubURL`) — auth, providers list, refresh.
/// - `provider`: the currently-selected provider's `base_url`. The `APIClient`
///   will throw a clear error if a provider call is sent before a provider has
///   been selected.
enum APITarget: Sendable {
    case hub
    case provider
}

struct Endpoint: Sendable {
    let method: HTTPMethod
    let path: String
    let target: APITarget
    var queryItems: [URLQueryItem]
    var body: Data?
    var requiresAuth: Bool

    init(
        method: HTTPMethod,
        path: String,
        target: APITarget,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        requiresAuth: Bool = true
    ) {
        self.method = method
        self.path = path
        self.target = target
        self.queryItems = queryItems
        self.body = body
        self.requiresAuth = requiresAuth
    }
}

extension Endpoint {
    /// Hub-targeted endpoint factories (auth + providers list).
    enum Hub {
        static func get(
            _ path: String,
            query: [URLQueryItem] = [],
            requiresAuth: Bool = true
        ) -> Endpoint {
            Endpoint(method: .get, path: path, target: .hub, queryItems: query, requiresAuth: requiresAuth)
        }

        static func post<B: Encodable>(
            _ path: String,
            body: B,
            requiresAuth: Bool = true
        ) throws -> Endpoint {
            let data = try JSONCoding.encoder.encode(body)
            return Endpoint(method: .post, path: path, target: .hub, body: data, requiresAuth: requiresAuth)
        }
    }

    /// Provider-targeted endpoint factories (catalog + orders).
    enum Provider {
        static func get(
            _ path: String,
            query: [URLQueryItem] = [],
            requiresAuth: Bool = true
        ) -> Endpoint {
            Endpoint(method: .get, path: path, target: .provider, queryItems: query, requiresAuth: requiresAuth)
        }

        static func post<B: Encodable>(
            _ path: String,
            body: B,
            requiresAuth: Bool = true
        ) throws -> Endpoint {
            let data = try JSONCoding.encoder.encode(body)
            return Endpoint(method: .post, path: path, target: .provider, body: data, requiresAuth: requiresAuth)
        }

        static func patch<B: Encodable>(
            _ path: String,
            body: B,
            requiresAuth: Bool = true
        ) throws -> Endpoint {
            let data = try JSONCoding.encoder.encode(body)
            return Endpoint(method: .patch, path: path, target: .provider, body: data, requiresAuth: requiresAuth)
        }
    }
}

/// Shared JSON encoder/decoder configured for the Inveasy API:
/// snake_case keys on the wire, camelCase in Swift, ISO 8601 dates.
///
/// The decoder uses a tolerant ISO 8601 date strategy: the API spec shows
/// dates like `2026-06-07T14:32:00Z`, but real responses occasionally include
/// fractional seconds (`...:32:00.123Z`). The default `.iso8601` strategy
/// rejects fractional seconds, which was breaking order detail decoding.
enum JSONCoding {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            for formatter in iso8601Formatters {
                if let date = formatter.date(from: raw) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Date string '\(raw)' is not a supported ISO 8601 format"
            )
        }
        return d
    }()

    private static let iso8601Formatters: [ISO8601DateFormatter] = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return [withFraction, standard]
    }()
}
