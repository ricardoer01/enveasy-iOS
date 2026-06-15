//
//  Money.swift
//  inveasy
//

import Foundation

/// Currency amount in centavos (1/100 of a peso).
///
/// The Inveasy API returns and accepts every monetary field as an integer in
/// cents (e.g. `1800` for `$18.00`). Use this type instead of `Int` or
/// `Decimal` so the unit of measure can't get lost on the way to/from views.
struct Money: Hashable, Sendable {
    let cents: Int

    init(cents: Int) {
        self.cents = cents
    }
}

extension Money: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.cents = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(cents)
    }
}

extension Money: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.cents = value
    }
}

extension Money {
    static let zero = Money(cents: 0)

    var decimal: Decimal {
        Decimal(cents) / 100
    }

    func formatted(
        currencyCode: String = "MXN",
        locale: Locale = Locale(identifier: "es_MX")
    ) -> String {
        decimal.formatted(.currency(code: currencyCode).locale(locale))
    }

    static func + (lhs: Money, rhs: Money) -> Money {
        Money(cents: lhs.cents + rhs.cents)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        Money(cents: lhs.cents - rhs.cents)
    }
}
