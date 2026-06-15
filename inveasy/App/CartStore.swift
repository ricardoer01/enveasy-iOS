//
//  CartStore.swift
//  inveasy
//

import Foundation
import Observation

/// Local-only shopping cart.
///
/// The Inveasy API has no cart endpoint — the cart only exists on the device
/// and is materialized into an order at checkout via `POST /orders`. We
/// persist to `UserDefaults` so the cart survives app restarts, and use a
/// dedicated JSON coder (not the snake_case API coder) since this is local
/// data, not wire data.
@MainActor
@Observable
final class CartStore {
    private(set) var lines: [CartLine] = []

    private let defaults: UserDefaults
    private let key = "cart_lines_v1"
    private let coder = LocalJSONCoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Derived state

    var isEmpty: Bool { lines.isEmpty }
    var lineCount: Int { lines.count }

    var subtotal: Money {
        Money(cents: lines.reduce(0) { $0 + $1.subtotal.cents })
    }

    // MARK: - Mutations

    /// Add `quantity` of `product` to the cart. If a line already exists for
    /// that product, the quantity is summed rather than duplicated.
    func add(product: Product, quantity: Decimal = 1, notes: String? = nil) {
        if let index = lines.firstIndex(where: { $0.productId == product.id }) {
            lines[index].quantity += quantity
            if let notes, !notes.isEmpty {
                lines[index].notes = notes
            }
        } else {
            let line = CartLine(
                id: UUID(),
                productId: product.id,
                productName: product.name,
                productSku: product.sku,
                imageUrl: product.imageUrl,
                unit: product.unit,
                unitPrice: product.price,
                quantity: max(quantity, 1),
                notes: notes
            )
            lines.append(line)
        }
        persist()
    }

    /// Set the quantity for a line. A non-positive quantity removes the line.
    func setQuantity(_ quantity: Decimal, for lineId: UUID) {
        guard let index = lines.firstIndex(where: { $0.id == lineId }) else { return }
        if quantity <= 0 {
            lines.remove(at: index)
        } else {
            lines[index].quantity = quantity
        }
        persist()
    }

    func remove(_ lineId: UUID) {
        lines.removeAll { $0.id == lineId }
        persist()
    }

    func clear() {
        lines = []
        persist()
    }

    /// Build the `CreateOrderRequest` payload that backs `POST /orders`.
    func makeOrderRequest(
        deliveryType: DeliveryType,
        shippingAddress: ShippingAddress?,
        pickupLocation: String? = nil,
        notes: String?
    ) -> CreateOrderRequest {
        let items = lines.map {
            CreateOrderItem(productId: $0.productId, quantity: $0.quantity, notes: $0.notes)
        }
        return CreateOrderRequest(
            items: items,
            deliveryType: deliveryType,
            shippingAddress: shippingAddress,
            pickupLocation: pickupLocation,
            notes: notes
        )
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? coder.encoder.encode(lines) else { return }
        defaults.set(data, forKey: key)
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? coder.decoder.decode([CartLine].self, from: data) else {
            return
        }
        lines = decoded
    }
}

/// Vanilla JSON coder for local persistence — no snake_case rewriting.
private struct LocalJSONCoder {
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
