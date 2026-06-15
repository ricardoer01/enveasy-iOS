//
//  Decoding.swift
//  inveasy
//

import Foundation

extension KeyedDecodingContainer {
    /// Decode a `Decimal` that the API may serialize as either a JSON number
    /// or a JSON string. The Inveasy backend (Postgres NUMERIC) sometimes
    /// emits values like `"3"` or `"0.5"` as strings to preserve precision,
    /// which the default `Decimal` decoder rejects with a type mismatch.
    func decodeFlexibleDecimal(forKey key: Key) throws -> Decimal {
        if let decimal = try? decode(Decimal.self, forKey: key) {
            return decimal
        }
        if let string = try? decode(String.self, forKey: key),
           let parsed = Decimal(string: string) {
            return parsed
        }
        throw DecodingError.typeMismatch(
            Decimal.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected number or numeric string for '\(key.stringValue)'"
            )
        )
    }
}
