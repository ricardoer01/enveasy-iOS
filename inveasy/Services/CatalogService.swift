//
//  CatalogService.swift
//  inveasy
//

import Foundation

/// Typed wrapper around the provider's `/catalog/*` endpoints.
///
/// All three endpoints are public — no Bearer token is required. We pass
/// `requiresAuth: false` so a signed-out user can browse the catalog without
/// triggering the client's "not signed in" guard.
struct CatalogService: Sendable {
    let client: APIClient

    func categories() async throws -> [Category] {
        let response: DataEnvelope<[Category]> = try await client.send(
            .Provider.get("catalog/categories", requiresAuth: false)
        )
        return response.data
    }

    func products(
        search: String? = nil,
        categoryId: UUID? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> (items: [Product], meta: PageMeta) {
        var query: [URLQueryItem] = []
        if let search, !search.isEmpty {
            query.append(URLQueryItem(name: "search", value: search))
        }
        if let categoryId {
            query.append(URLQueryItem(name: "category_id", value: categoryId.uuidString))
        }
        query.append(URLQueryItem(name: "page", value: String(page)))
        query.append(URLQueryItem(name: "per_page", value: String(perPage)))

        let response: PageEnvelope<Product> = try await client.send(
            .Provider.get("catalog/products", query: query, requiresAuth: false)
        )
        return (response.data, response.meta)
    }

    func product(id: UUID) async throws -> Product {
        let response: DataEnvelope<Product> = try await client.send(
            .Provider.get("catalog/products/\(id.uuidString)", requiresAuth: false)
        )
        return response.data
    }
}
