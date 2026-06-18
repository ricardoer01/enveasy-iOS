//
//  AddressCompleter.swift
//  inveasy
//

import Foundation
import MapKit
import Observation

/// SwiftUI-friendly wrapper around `MKLocalSearchCompleter`.
///
/// Exposes the live result list as an `@Observable` property, and provides an
/// async `resolve(_:)` that runs a full `MKLocalSearch` against a chosen
/// completion to obtain a `CLPlacemark` — which has the structured fields
/// (thoroughfare, locality, postal code, …) we need to populate the address
/// form.
///
/// The NSObject-based delegate is kept as a private inner type to avoid
/// forcing the public wrapper to inherit `NSObject`.
@MainActor
@Observable
final class AddressCompleter {

    /// Last-known list of completions. Updates as the user types.
    private(set) var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private var delegate: Delegate?

    init() {
        let delegate = Delegate { [weak self] results in
            self?.results = results
        }
        self.delegate = delegate
        completer.delegate = delegate
        completer.resultTypes = .address
    }

    /// Feed a new query to the completer. Empty/whitespace queries clear the
    /// suggestion list without dispatching a search.
    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completer.queryFragment = ""
            results = []
            return
        }
        completer.queryFragment = trimmed
    }

    /// Clear the suggestion list (e.g. after the user picks a suggestion).
    func clear() {
        completer.queryFragment = ""
        results = []
    }

    /// Resolve a completion into a full placemark. Use the placemark's named
    /// fields to populate `line1`, `city`, `state`, `zip`, etc.
    func resolve(_ completion: MKLocalSearchCompletion) async throws -> CLPlacemark? {
        let request = MKLocalSearch.Request(completion: completion)
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.first?.placemark
    }

    // MARK: - Delegate bridge

    private final class Delegate: NSObject, MKLocalSearchCompleterDelegate {
        let onResults: @MainActor ([MKLocalSearchCompletion]) -> Void

        init(onResults: @escaping @MainActor ([MKLocalSearchCompletion]) -> Void) {
            self.onResults = onResults
        }

        nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            let results = completer.results
            Task { @MainActor in onResults(results) }
        }

        nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
            // Common when the user types too quickly or has no network.
            // Swallow the error and clear suggestions so we don't show stale ones.
            Task { @MainActor in onResults([]) }
        }
    }
}
