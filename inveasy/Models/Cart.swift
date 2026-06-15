//
//  Cart.swift
//  inveasy
//

import Foundation

/// One line in the local shopping cart.
///
/// Stores a snapshot of product display info so the cart still renders if a
/// product is later modified server-side. The actual order total is recomputed
/// by the backend at checkout — the `subtotal` here is just a display estimate.
struct CartLine: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let productId: UUID
    let productName: String
    let productSku: String
    let imageUrl: URL?
    let unit: ProductUnit
    let unitPrice: Money
    var quantity: Decimal
    var notes: String?

    var subtotal: Money {
        let raw = Decimal(unitPrice.cents) * quantity
        return Money(cents: NSDecimalNumber(decimal: raw).intValue)
    }
}
