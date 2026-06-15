//
//  ProviderStore.swift
//  inveasy
//

import Foundation
import Observation

/// Owns the provider selection state.
///
/// Lifecycle:
/// 1. `.idle` on init.
/// 2. `bootstrap()` fetches the providers list from the hub. The
///    previously-selected provider id (persisted in UserDefaults) is consulted:
///    if it still exists in the new list, we re-select it immediately. If it
///    doesn't, or there's no cached selection, we surface
///    `.selecting(providers:)` so the user can pick.
/// 3. `select(_:)` writes the chosen provider's base URL into the `APIClient`,
///    persists `provider.id`, and moves to `.selected(provider)`.
@MainActor
@Observable
final class ProviderStore {

    enum State: Equatable {
        case idle
        case loading
        case selecting(providers: [Provider])
        case selected(Provider)
        case failed(message: String)
    }

    private let client: APIClient
    private let defaults: UserDefaults
    private let storageKey = "selected_provider_id"

    var state: State = .idle

    init(client: APIClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
    }

    /// Currently-selected provider, if any.
    var current: Provider? {
        if case .selected(let provider) = state { return provider }
        return nil
    }

    func bootstrap() async {
        switch state {
        case .selected, .loading:
            return
        default:
            break
        }

        state = .loading
        do {
            let service = ProviderService(client: client)
            let providers = try await service.providers()
            guard !providers.isEmpty else {
                state = .failed(message: "No hay proveedores disponibles.")
                return
            }

            let savedID = defaults.string(forKey: storageKey)
            if let savedID, let match = providers.first(where: { $0.id == savedID }) {
                await applySelection(match)
                return
            }

            if providers.count == 1 {
                await applySelection(providers[0])
                return
            }

            state = .selecting(providers: providers)
        } catch let error as APIError {
            state = .failed(message: error.errorDescription ?? "No se pudieron cargar los proveedores.")
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// User picked a provider from the list — persist and route the client.
    func select(_ provider: Provider) async {
        await applySelection(provider)
    }

    /// Drop the current selection (e.g. user wants to switch providers).
    /// Re-runs the provider list fetch.
    func clearSelection() async {
        defaults.removeObject(forKey: storageKey)
        await client.setProviderURL(nil)
        state = .idle
        await bootstrap()
    }

    private func applySelection(_ provider: Provider) async {
        // The hub returns `base_url` as a bare host (e.g. `https://storea.inveasy.com`).
        // Catalog and order paths are versioned, so the provider's API root is
        // `{base_url}/api/v1`. Append the version unless the URL already
        // includes it (some providers may pre-version their `base_url`).
        let apiURL: URL = provider.baseURL.path.contains("/api/v1")
            ? provider.baseURL
            : provider.baseURL.appendingPathComponent("api/v1")
        await client.setProviderURL(apiURL)
        defaults.set(provider.id, forKey: storageKey)
        state = .selected(provider)
    }
}
