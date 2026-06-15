//
//  ProviderService.swift
//  inveasy
//

import Foundation

/// Typed wrapper around the hub's providers registry.
struct ProviderService: Sendable {
    let client: APIClient

    /// Fetch the active providers list. No auth required.
    func providers() async throws -> [Provider] {
        let response: DataEnvelope<[Provider]> = try await client.send(
            .Hub.get("providers", requiresAuth: false)
        )
        return response.data
    }
}
