//
//  Catalog.swift
//  inveasy
//

import Foundation

/// Product unit of measure. Each provider can define its own units (`"pza"`,
/// `"kg"`, `"bottle"`, etc.) so we wrap a raw string and treat a handful of
/// values specially for fractional-quantity logic and Spanish display labels.
struct ProductUnit: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Spanish label shown to customers. Falls back to the raw value for
    /// units we don't have a canonical translation for.
    var displayName: String {
        switch rawValue.lowercased() {
        case "pza", "piece", "unit", "u":    return "pza"
        case "kg":                            return "kg"
        case "lt", "l", "liter", "litre":     return "lt"
        case "caja", "box":                   return "caja"
        case "m":                             return "m"
        case "m²", "m2":                      return "m²"
        case "hr", "hour", "h":               return "hr"
        case "bottle":                        return "botella"
        case "pack", "paquete":               return "paquete"
        default:                              return rawValue
        }
    }

    /// Units that accept fractional quantities in order items.
    var allowsFractional: Bool {
        switch rawValue.lowercased() {
        case "kg", "lt", "l", "liter", "litre", "m", "m²", "m2": return true
        default: return false
        }
    }
}

struct Category: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let name: String
    let slug: String
    let description: String?
    let active: Bool
    let createdAt: Date
}

struct Product: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let name: String
    let sku: String
    let description: String?
    let descriptionLong: String?
    let unit: ProductUnit
    let price: Money
    let stockQuantity: Decimal
    let imageUrl: URL?
    let categoryId: UUID
    let categoryName: String

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.sku = try c.decode(String.self, forKey: .sku)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.descriptionLong = try c.decodeIfPresent(String.self, forKey: .descriptionLong)
        self.unit = try c.decode(ProductUnit.self, forKey: .unit)
        self.price = try c.decode(Money.self, forKey: .price)
        self.stockQuantity = try c.decodeFlexibleDecimal(forKey: .stockQuantity)
        self.imageUrl = try c.decodeIfPresent(URL.self, forKey: .imageUrl)
        self.categoryId = try c.decode(UUID.self, forKey: .categoryId)
        self.categoryName = try c.decode(String.self, forKey: .categoryName)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, sku, description, descriptionLong
        case unit, price, stockQuantity, imageUrl, categoryId, categoryName
    }
}

extension Product {
    /// Below this quantity, surface a low-stock warning in the UI. Held as
    /// a single source of truth so the badge in the detail view and the
    /// overlay on the catalog card stay in sync.
    static let lowStockThreshold: Decimal = 10

    var isInStock: Bool { stockQuantity > 0 }

    /// True when there's stock remaining but it's below the warning
    /// threshold. Explicitly excludes the zero case so out-of-stock
    /// products fall through to the "Agotado" treatment instead of a
    /// nonsensical "low" indicator on an empty shelf.
    var isLowStock: Bool {
        stockQuantity > 0 && stockQuantity < Product.lowStockThreshold
    }
}
