//
//  APIClient.swift
//  inveasy
//

import Foundation

/// Async/await HTTP client for the Inveasy API.
///
/// Topology:
/// - **Hub** (`hubURL`): a build-time constant. Auth and the providers list
///   live here. Refresh always runs against the hub regardless of which
///   provider the user is currently browsing.
/// - **Provider** (`providerURL`): set at runtime once a provider has been
///   selected. Catalog and orders run against this base. Provider-targeted
///   endpoints throw `APIError.transport` until a provider is set.
///
/// Behavior:
/// - Adds `Authorization: Bearer <access_token>` to authenticated endpoints.
/// - On a 401 from an authenticated endpoint, performs a single-flight refresh
///   against the hub, persists the rotated token pair, and retries the
///   original request once.
/// - If refresh fails (token expired, revoked, or already used), tokens are
///   cleared and the caller receives `.unauthorized`.
actor APIClient {
    static let defaultHubURL = URL(string: "https://nextjs-dashboard-rouge-one-58.vercel.app/api/v1")!

    private let hubURL: URL
    private var providerURL: URL?
    private let session: URLSession
    private let tokenStorage: TokenStorage
    private var refreshTask: Task<TokenPair, Error>?

    init(
        hubURL: URL = APIClient.defaultHubURL,
        providerURL: URL? = nil,
        session: URLSession = .shared,
        tokenStorage: TokenStorage = TokenStorage()
    ) {
        self.hubURL = hubURL
        self.providerURL = providerURL
        self.session = session
        self.tokenStorage = tokenStorage
    }

    // MARK: - Public API

    /// Send a request and decode the response body as `T`.
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let data = try await rawSend(endpoint)
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decoding(
                message: "Failed to decode \(T.self): \(Self.describe(error))"
            )
        } catch {
            throw APIError.decoding(
                message: "Failed to decode \(T.self): \(error.localizedDescription)"
            )
        }
    }

    /// Send a request and discard the response body.
    func send(_ endpoint: Endpoint) async throws {
        _ = try await rawSend(endpoint)
    }

    /// Set the currently-selected provider's API base URL. `nil` unselects.
    /// Provider-targeted endpoints will throw until this has been set.
    func setProviderURL(_ url: URL?) {
        self.providerURL = url
    }

    /// Replace the stored token pair (e.g. after a successful login/register).
    func setTokens(_ pair: TokenPair) throws {
        try tokenStorage.save(pair)
    }

    /// Clear the stored token pair (e.g. after logout).
    func clearTokens() throws {
        try tokenStorage.clear()
    }

    /// Whether a token pair is currently persisted.
    func hasTokens() -> Bool {
        (try? tokenStorage.load()) != nil
    }

    /// Returns the persisted token pair, if any. Used by sign-out to revoke
    /// the refresh token server-side.
    func currentTokens() -> TokenPair? {
        try? tokenStorage.load()
    }

    // MARK: - Core request flow

    private func rawSend(_ endpoint: Endpoint) async throws -> Data {
        let request = try buildRequest(for: endpoint)
        let (data, response) = try await perform(request)

        if let http = response as? HTTPURLResponse,
           http.statusCode == 401,
           endpoint.requiresAuth {
            try await refreshTokens()
            let retryRequest = try buildRequest(for: endpoint)
            let (retryData, retryResponse) = try await perform(retryRequest)
            return try validate(retryResponse, data: retryData)
        }

        return try validate(response, data: data)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            // Treat task/URLSession cancellation as a control-flow signal,
            // not a transport error. Callers can ignore `CancellationError`
            // (e.g. when a debounced search supersedes an in-flight request)
            // without surfacing a spurious "Cancelled" alert.
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw APIError.transport(message: error.localizedDescription)
        }
    }

    private func validate(_ response: URLResponse, data: Data) throws -> Data {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(message: "Missing HTTP response")
        }
        if (200..<300).contains(http.statusCode) {
            return data
        }

        let body = try? JSONCoding.decoder.decode(APIErrorBody.self, from: data)
        let message = body?.error ?? "HTTP \(http.statusCode)"

        switch http.statusCode {
        case 401:
            throw APIError.unauthorized(message: message)
        case 404:
            throw APIError.notFound(message: message)
        case 409:
            throw APIError.conflict(message: message)
        case 422:
            throw APIError.validation(message: message, details: body?.details ?? [:])
        default:
            throw APIError.server(status: http.statusCode, message: message)
        }
    }

    /// Resolve the base URL the endpoint should hit.
    private func baseURL(for target: APITarget) throws -> URL {
        switch target {
        case .hub:
            return hubURL
        case .provider:
            guard let providerURL else {
                throw APIError.transport(message: "No provider selected")
            }
            return providerURL
        }
    }

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        let base = try baseURL(for: endpoint.target)
        let fullURL = base.appendingPathComponent(endpoint.path)
        guard var components = URLComponents(url: fullURL, resolvingAgainstBaseURL: false) else {
            throw APIError.transport(message: "Invalid URL for path: \(endpoint.path)")
        }
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else {
            throw APIError.transport(message: "Invalid URL components for path: \(endpoint.path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if endpoint.requiresAuth {
            guard let tokens = try tokenStorage.load() else {
                throw APIError.unauthorized(message: "Not signed in")
            }
            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Token refresh (single-flight)

    @discardableResult
    private func refreshTokens() async throws -> TokenPair {
        if let inFlight = refreshTask {
            return try await inFlight.value
        }

        let task = Task<TokenPair, Error> {
            defer { refreshTask = nil }
            return try await performRefresh()
        }
        refreshTask = task

        do {
            return try await task.value
        } catch {
            try? tokenStorage.clear()
            throw APIError.unauthorized(message: "Session expired")
        }
    }

    /// Refresh always runs against the hub regardless of the request that
    /// triggered the 401.
    private func performRefresh() async throws -> TokenPair {
        guard let current = try tokenStorage.load() else {
            throw APIError.unauthorized(message: "Not signed in")
        }

        let payload = ["refresh_token": current.refreshToken]
        let body = try JSONCoding.encoder.encode(payload)
        let endpoint = Endpoint(
            method: .post,
            path: "auth/refresh",
            target: .hub,
            body: body,
            requiresAuth: false
        )

        let request = try buildRequest(for: endpoint)
        let (data, response) = try await perform(request)
        let validated = try validate(response, data: data)

        let parsed = try JSONCoding.decoder.decode(RefreshResponse.self, from: validated)
        let pair = TokenPair(
            accessToken: parsed.accessToken,
            refreshToken: parsed.refreshToken
        )
        try tokenStorage.save(pair)
        return pair
    }

    private struct RefreshResponse: Decodable {
        let accessToken: String
        let refreshToken: String
    }

    // MARK: - Decoding error formatter

    /// Produce a developer-friendly summary of a `DecodingError` that names
    /// the failing coding path. The default `localizedDescription` collapses
    /// to a generic "data couldn't be read" string that hides the actual key.
    private static func describe(_ error: DecodingError) -> String {
        func pathString(_ keys: [CodingKey]) -> String {
            keys.isEmpty ? "<root>" : keys.map(\.stringValue).joined(separator: ".")
        }
        switch error {
        case .typeMismatch(let type, let ctx):
            return "type mismatch for \(type) at \(pathString(ctx.codingPath)): \(ctx.debugDescription)"
        case .valueNotFound(let type, let ctx):
            return "missing value for \(type) at \(pathString(ctx.codingPath)): \(ctx.debugDescription)"
        case .keyNotFound(let key, let ctx):
            return "missing key '\(key.stringValue)' at \(pathString(ctx.codingPath))"
        case .dataCorrupted(let ctx):
            return "data corrupted at \(pathString(ctx.codingPath)): \(ctx.debugDescription)"
        @unknown default:
            return "unknown decoding error"
        }
    }
}
