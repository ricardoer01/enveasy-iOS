//
//  AppState.swift
//  inveasy
//

import Foundation
import Observation

/// Root app state. Tracks whether a customer is signed in and exposes the
/// `APIClient` used by all screens.
@MainActor
@Observable
final class AppState {

    enum Auth: Equatable {
        case bootstrapping
        case signedOut
        case signedIn(Customer)
    }

    let client: APIClient
    let providers: ProviderStore
    private let profile: ProfileStore

    var auth: Auth = .bootstrapping

    init(client: APIClient = APIClient(), profile: ProfileStore = ProfileStore()) {
        self.client = client
        self.profile = profile
        self.providers = ProviderStore(client: client)
    }

    /// Read persisted state once on app launch and decide which root view to show.
    func bootstrap() async {
        let hasTokens = await client.hasTokens()
        if hasTokens, let customer = profile.load() {
            auth = .signedIn(customer)
            // The token pair survived from a previous launch — arm the
            // proactive refresh timer so the session stays fresh.
            await client.startProactiveRefresh()
        } else {
            // Tokens without profile, or profile without tokens, means we're in
            // an inconsistent state — clear both and start fresh.
            try? await client.clearTokens()
            profile.clear()
            auth = .signedOut
        }
    }

    func signIn(email: String, password: String) async throws {
        let request = LoginRequest(email: email, password: password)
        let endpoint = try Endpoint.Hub.post("auth/login", body: request, requiresAuth: false)
        let session = try await client.send(endpoint, as: AuthSession.self)
        try await persist(session)
    }

    /// Step 1 of registration. Creates the customer in `pending_verification`
    /// and triggers the email-code send. Returns the `customerId` the caller
    /// must pass to `verifyEmail` along with the user's 6-digit code.
    func register(name: String, email: String, password: String, phone: String) async throws -> UUID {
        let request = RegisterRequest(name: name, email: email, password: password, phone: phone)
        let endpoint = try Endpoint.Hub.post("auth/register", body: request, requiresAuth: false)
        let response = try await client.send(endpoint, as: RegisterResponse.self)
        return response.customerId
    }

    /// Step 2 of registration. Trades the `customerId` from `register` plus the
    /// user's 6-digit code for an `AuthSession`, persists tokens, and flips
    /// auth state to `.signedIn`.
    func verifyEmail(customerID: UUID, code: String) async throws {
        let request = VerifyEmailRequest(customerId: customerID, code: code)
        let endpoint = try Endpoint.Hub.post("auth/verify-email", body: request, requiresAuth: false)
        let session = try await client.send(endpoint, as: AuthSession.self)
        try await persist(session)
    }

    /// Best-effort sign out: revoke the refresh token server-side, then drop
    /// local state regardless of the network result.
    func signOut() async {
        if let tokens = await client.currentTokens(),
           let endpoint = try? Endpoint.Hub.post(
            "auth/logout",
            body: LogoutRequest(refreshToken: tokens.refreshToken),
            requiresAuth: false
           ) {
            _ = try? await client.send(endpoint)
        }
        try? await client.clearTokens()
        profile.clear()
        auth = .signedOut
    }

    private func persist(_ session: AuthSession) async throws {
        try await client.setTokens(
            TokenPair(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken
            )
        )
        profile.save(session.customer)
        auth = .signedIn(session.customer)
    }
}
