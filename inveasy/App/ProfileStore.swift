//
//  ProfileStore.swift
//  inveasy
//

import Foundation

/// Persists the current `Customer` profile in `UserDefaults`.
///
/// Tokens live in the Keychain (see `TokenStorage`). The customer profile
/// itself is not a credential, so `UserDefaults` is fine — and it makes the
/// "remember the signed-in user across launches" path trivial.
struct ProfileStore {
    private let defaults: UserDefaults
    private let key = "current_customer"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Customer? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONCoding.decoder.decode(Customer.self, from: data)
    }

    func save(_ customer: Customer) {
        guard let data = try? JSONCoding.encoder.encode(customer) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
