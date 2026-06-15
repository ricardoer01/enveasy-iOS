//
//  OrderService.swift
//  inveasy
//

import Foundation

/// Typed wrapper around the provider's `/orders/*` endpoints. All endpoints
/// require a Bearer token; the client handles the refresh + retry dance.
struct OrderService: Sendable {
    let client: APIClient

    func placeOrder(_ request: CreateOrderRequest) async throws -> CreatedOrder {
        let endpoint = try Endpoint.Provider.post("orders", body: request)
        let response: DataEnvelope<CreatedOrder> = try await client.send(endpoint)
        return response.data
    }

    func orders(page: Int = 1, perPage: Int = 20) async throws -> (items: [OrderSummary], meta: PageMeta) {
        let query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        let response: PageEnvelope<OrderSummary> = try await client.send(
            .Provider.get("orders", query: query)
        )
        return (response.data, response.meta)
    }

    func order(id: UUID) async throws -> Order {
        let response: DataEnvelope<Order> = try await client.send(
            .Provider.get("orders/\(id.uuidString)")
        )
        return response.data
    }

    /// Customer-initiated cancel. Only valid for `pending` and `confirmed`
    /// orders — anything else returns 409 from the API.
    func cancel(id: UUID, reason: String?) async throws -> OrderStatusUpdate {
        let endpoint = try Endpoint.Provider.patch(
            "orders/\(id.uuidString)",
            body: CancelOrderRequest(cancellationReason: reason)
        )
        let response: DataEnvelope<OrderStatusUpdate> = try await client.send(endpoint)
        return response.data
    }
}
