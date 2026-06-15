//
//  Order.swift
//  inveasy
//

import Foundation

enum OrderStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case pending
    case confirmed
    case processing
    case ready
    case shipped
    case delivered
    case paid
    case cancelled

    /// Spanish customer-facing label.
    var displayName: String {
        switch self {
        case .pending: return "Pendiente"
        case .confirmed: return "Confirmado"
        case .processing: return "En preparación"
        case .ready: return "Listo para recoger"
        case .shipped: return "En camino"
        case .delivered: return "Entregado"
        case .paid: return "Pagado"
        case .cancelled: return "Cancelado"
        }
    }

    /// The Inveasy API only accepts customer-initiated cancellation while the
    /// order is in `pending` or `confirmed`. Any other state returns 409.
    var isCancellableByCustomer: Bool {
        self == .pending || self == .confirmed
    }
}

/// Structured shipping address per the `POST /orders` and `GET /orders/:id`
/// contracts.
///
/// New orders are written as proper JSON objects. **Legacy orders** still
/// carry `shipping_address` as a JSON-encoded string (the backend previously
/// stringified the structured payload before storing it). The polymorphic
/// decoder accepts either shape so we can render history without backfilling
/// the database.
struct ShippingAddress: Codable, Hashable, Sendable {
    let line1: String?
    let line2: String?
    let street: String?
    let street2: String?
    let neighborhood: String?
    let city: String?
    let state: String?
    let zip: String?
    let country: String?
    let references: String?

    init(
        line1: String? = nil,
        line2: String? = nil,
        street: String? = nil,
        street2: String? = nil,
        neighborhood: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zip: String? = nil,
        country: String? = nil,
        references: String? = nil
    ) {
        self.line1 = line1
        self.line2 = line2
        self.street = street
        self.street2 = street2
        self.neighborhood = neighborhood
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
        self.references = references
    }

    init(from decoder: any Decoder) throws {
        // New writes: structured JSON object.
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
            self.line1 = try keyed.decodeIfPresent(String.self, forKey: .line1)
            self.line2 = try keyed.decodeIfPresent(String.self, forKey: .line2)
            self.street = try keyed.decodeIfPresent(String.self, forKey: .street)
            self.street2 = try keyed.decodeIfPresent(String.self, forKey: .street2)
            self.neighborhood = try keyed.decodeIfPresent(String.self, forKey: .neighborhood)
            self.city = try keyed.decodeIfPresent(String.self, forKey: .city)
            self.state = try keyed.decodeIfPresent(String.self, forKey: .state)
            self.zip = try keyed.decodeIfPresent(String.self, forKey: .zip)
            self.country = try keyed.decodeIfPresent(String.self, forKey: .country)
            self.references = try keyed.decodeIfPresent(String.self, forKey: .references)
            return
        }

        // Legacy rows: `shipping_address` is a string. It may be a JSON-encoded
        // address object (parse and lift fields) or a single-line free-form
        // address (drop into `line1`).
        let single = try decoder.singleValueContainer()
        let raw = try single.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.hasPrefix("{"),
           let data = raw.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.line1 = Self.cleanString(dict["line1"])
            self.line2 = Self.cleanString(dict["line2"])
            self.street = Self.cleanString(dict["street"])
            self.street2 = Self.cleanString(dict["street2"])
            self.neighborhood = Self.cleanString(dict["neighborhood"])
            self.city = Self.cleanString(dict["city"])
            self.state = Self.cleanString(dict["state"])
            self.zip = Self.cleanString(dict["zip"])
            self.country = Self.cleanString(dict["country"])
            self.references = Self.cleanString(dict["references"])
            return
        }

        self.line1 = raw.isEmpty ? nil : raw
        self.line2 = nil
        self.street = nil
        self.street2 = nil
        self.neighborhood = nil
        self.city = nil
        self.state = nil
        self.zip = nil
        self.country = nil
        self.references = nil
    }

    private static func cleanString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(line1, forKey: .line1)
        try container.encodeIfPresent(line2, forKey: .line2)
        try container.encodeIfPresent(street, forKey: .street)
        try container.encodeIfPresent(street2, forKey: .street2)
        try container.encodeIfPresent(neighborhood, forKey: .neighborhood)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(zip, forKey: .zip)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encodeIfPresent(references, forKey: .references)
    }

    private enum CodingKeys: String, CodingKey {
        case line1, line2
        case street, street2, neighborhood, city, state, zip, country, references
    }
}

// MARK: - List

/// Row shape from `GET /orders`.
struct OrderSummary: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let orderNumber: String
    let customerName: String
    let customerEmail: String
    let status: OrderStatus
    let deliveryType: DeliveryType
    let total: Money
    let itemCount: Int
    let placedAt: Date
}

// MARK: - Detail

/// Full shape from `GET /orders/:id`.
struct Order: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let orderNumber: String
    let customerId: UUID
    let status: OrderStatus
    let deliveryType: DeliveryType
    let pickupLocation: String?
    let subtotal: Money
    let tax: Money
    let discount: Money
    let total: Money
    let shippingAddress: ShippingAddress?
    let notes: String?
    let placedAt: Date
    let confirmedAt: Date?
    let readyForPickupAt: Date?
    let shippedAt: Date?
    let deliveredAt: Date?
    let paidAt: Date?
    let cancelledAt: Date?
    let cancellationReason: String?
    let createdAt: Date?
    let updatedAt: Date?
    let customerName: String
    let customerEmail: String
    let customerPhone: String?
    let items: [OrderItem]
}

struct OrderItem: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let orderId: UUID?
    let productId: UUID
    let productName: String
    let productSku: String
    let unit: ProductUnit
    let unitPrice: Money
    let quantity: Decimal
    let subtotal: Money
    let notes: String?

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.orderId = try c.decodeIfPresent(UUID.self, forKey: .orderId)
        self.productId = try c.decode(UUID.self, forKey: .productId)
        self.productName = try c.decode(String.self, forKey: .productName)
        self.productSku = try c.decode(String.self, forKey: .productSku)
        self.unit = try c.decode(ProductUnit.self, forKey: .unit)
        self.unitPrice = try c.decode(Money.self, forKey: .unitPrice)
        self.quantity = try c.decodeFlexibleDecimal(forKey: .quantity)
        self.subtotal = try c.decode(Money.self, forKey: .subtotal)
        self.notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case id, orderId, productId, productName, productSku
        case unit, unitPrice, quantity, subtotal, notes
    }
}

// MARK: - Create

/// Required on every `POST /orders` request. Drives whether the API expects a
/// `shipping_address` (delivery) or accepts an optional `pickup_location`
/// (pickup).
enum DeliveryType: String, Codable, Sendable, CaseIterable, Hashable {
    case pickup
    case delivery
}

struct CreateOrderRequest: Encodable, Sendable {
    let items: [CreateOrderItem]
    let deliveryType: DeliveryType
    let shippingAddress: ShippingAddress?
    let pickupLocation: String?
    let notes: String?

    init(
        items: [CreateOrderItem],
        deliveryType: DeliveryType,
        shippingAddress: ShippingAddress? = nil,
        pickupLocation: String? = nil,
        notes: String? = nil
    ) {
        self.items = items
        self.deliveryType = deliveryType
        self.shippingAddress = shippingAddress
        self.pickupLocation = pickupLocation
        self.notes = notes
    }
}

struct CreateOrderItem: Encodable, Sendable {
    let productId: UUID
    let quantity: Decimal
    let notes: String?

    init(productId: UUID, quantity: Decimal, notes: String? = nil) {
        self.productId = productId
        self.quantity = quantity
        self.notes = notes
    }
}

/// Response body from `POST /orders`.
struct CreatedOrder: Decodable, Sendable {
    let id: UUID
    let orderNumber: String
    let status: OrderStatus
    let deliveryType: DeliveryType
    let pickupLocation: String?
    let subtotal: Money
    let tax: Money
    let discount: Money
    let total: Money
    let placedAt: Date
}

// MARK: - Cancel

struct CancelOrderRequest: Encodable, Sendable {
    let status: String
    let cancellationReason: String?

    init(cancellationReason: String? = nil) {
        self.status = "cancelled"
        self.cancellationReason = cancellationReason
    }
}

/// Response body from `PATCH /orders/:id`.
struct OrderStatusUpdate: Decodable, Sendable {
    let id: UUID
    let status: OrderStatus
}
