//
//  CheckoutView.swift
//  inveasy
//

import SwiftUI
import MapKit

struct CheckoutView: View {
    @Environment(AppState.self) private var app
    @Environment(CartStore.self) private var cart
    @Environment(\.dismiss) private var dismiss

    @State private var fulfillment: DeliveryType = .pickup

    @State private var line1 = ""
    @State private var line2 = ""
    @State private var neighborhood = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var country = "México"
    @State private var references = ""

    @State private var pickupLocation = ""
    @State private var notes = ""

    @State private var addressCompleter = AddressCompleter()
    /// One-shot flag that swallows the `onChange` that fires immediately
    /// after `applySuggestion` writes back to `line1`. Without it, the
    /// programmatic write would re-trigger the completer and re-populate
    /// suggestions for the address the user just picked.
    @State private var suppressNextCompleterUpdate = false
    /// Whether the "Editar detalles" disclosure (city/state/zip/country/
    /// neighborhood) is expanded. Stays collapsed in the autocomplete-happy
    /// path; auto-expands when validation needs the user's attention on a
    /// hidden field.
    @State private var showAddressDetails = false

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var placedOrder: CreatedOrder?

    var body: some View {
        NavigationStack {
            Group {
                if let placedOrder {
                    SuccessView(order: placedOrder, onClose: dismissAndClear)
                } else {
                    Form {
                        Section("Resumen") {
                            LabeledContent("Productos") {
                                Text("\(cart.lineCount)")
                            }
                            LabeledContent("Subtotal") {
                                Text(cart.subtotal.formatted()).bold()
                            }
                            Text("El total final lo calcula el sistema al confirmar.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Section("Tipo de pedido") {
                            Picker("Tipo", selection: $fulfillment) {
                                Text("Recoger en tienda").tag(DeliveryType.pickup)
                                Text("Envío a domicilio").tag(DeliveryType.delivery)
                            }
                            .pickerStyle(.segmented)
                        }

                        if fulfillment == .delivery {
                            Section("Dirección de envío") {
                                TextField("Dirección", text: $line1)
                                    .textContentType(.streetAddressLine1)
                                    .onChange(of: line1) { _, newValue in
                                        if suppressNextCompleterUpdate {
                                            suppressNextCompleterUpdate = false
                                            return
                                        }
                                        addressCompleter.update(query: newValue)
                                    }

                                ForEach(addressCompleter.results, id: \.self) { completion in
                                    Button {
                                        Task { await applySuggestion(completion) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(completion.title)
                                                .foregroundStyle(.primary)
                                            if !completion.subtitle.isEmpty {
                                                Text(completion.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }

                                TextField("Interior / Depto. (opcional)", text: $line2)
                                    .textContentType(.streetAddressLine2)
                                TextField("Referencias (opcional)", text: $references, axis: .vertical)
                                    .lineLimit(2...4)

                                DisclosureGroup("Editar detalles", isExpanded: $showAddressDetails) {
                                    TextField("Colonia", text: $neighborhood)
                                    TextField("Ciudad", text: $city)
                                        .textContentType(.addressCity)
                                    TextField("Estado", text: $state)
                                        .textContentType(.addressState)
                                    TextField("Código postal", text: $zip)
                                        .keyboardType(.numberPad)
                                        .textContentType(.postalCode)
                                    TextField("País", text: $country)
                                        .textContentType(.countryName)
                                }
                            }
                        } else {
                            Section("Sucursal de recogida (opcional)") {
                                TextField("Nombre de la sucursal", text: $pickupLocation)
                            }
                        }

                        Section("Notas (opcional)") {
                            TextField("Indicaciones para la entrega", text: $notes, axis: .vertical)
                                .lineLimit(2...5)
                        }

                        if let errorMessage {
                            Section {
                                Text(errorMessage).foregroundStyle(.red)
                            }
                        }

                        Section {
                            Button(action: submit) {
                                HStack {
                                    Spacer()
                                    if isSubmitting {
                                        ProgressView()
                                    } else {
                                        Text("Confirmar pedido").bold()
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(isSubmitting || cart.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle(placedOrder == nil ? "Finalizar pedido" : "¡Pedido recibido!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if placedOrder == nil {
                        Button("Cancelar") { dismiss() }
                            .disabled(isSubmitting)
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    private func submit() {
        // Client-side guard: a delivery order needs at least the four core
        // address fields. Catching this here keeps us from sending an order
        // we know the API will reject (and gives a clearer message than the
        // backend's generic "Validation failed").
        if fulfillment == .delivery, let missing = missingDeliveryFields() {
            errorMessage = "Completa los campos requeridos: \(missing.joined(separator: ", "))."
            // If any of the missing fields lives inside the disclosure,
            // expand it so the user can see what to fill.
            let hiddenFieldsMissing = !Set(missing).isDisjoint(with: ["ciudad", "estado", "código postal"])
            if hiddenFieldsMissing {
                showAddressDetails = true
            }
            Haptics.notify(.error)
            return
        }

        let address = fulfillment == .delivery ? buildAddress() : nil
        let trimmedLocation = pickupLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = fulfillment == .pickup && !trimmedLocation.isEmpty ? trimmedLocation : nil
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = cart.makeOrderRequest(
            deliveryType: fulfillment,
            shippingAddress: address,
            pickupLocation: location,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )

        Task { @MainActor in
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                let service = OrderService(client: app.client)
                let created = try await service.placeOrder(request)
                cart.clear()
                placedOrder = created
                Haptics.notify(.success)
            } catch let error as APIError {
                errorMessage = error.errorDescription
                Haptics.notify(.error)
            } catch {
                errorMessage = error.localizedDescription
                Haptics.notify(.error)
            }
        }
    }

    /// Pick a completer suggestion, resolve it to a placemark, and populate
    /// the structured form fields. Treated as best-effort: any individual
    /// field that's missing on the placemark stays untouched so the user can
    /// fill it manually.
    private func applySuggestion(_ completion: MKLocalSearchCompletion) async {
        do {
            guard let placemark = try await addressCompleter.resolve(completion) else { return }
            let street = [placemark.subThoroughfare, placemark.thoroughfare]
                .compactMap { $0 }
                .joined(separator: " ")
            // Stop the next onChange from re-firing the completer with the
            // value we're about to write.
            if !street.isEmpty {
                suppressNextCompleterUpdate = true
                line1 = street
            }
            if let locality = placemark.locality { city = locality }
            if let admin = placemark.administrativeArea { state = admin }
            if let postal = placemark.postalCode { zip = postal }
            if let nation = placemark.country { country = nation }
            if let subLocality = placemark.subLocality, neighborhood.isEmpty {
                neighborhood = subLocality
            }
            addressCompleter.clear()
            Haptics.impact(.light)
        } catch {
            // Resolution failures aren't worth surfacing — the user can still
            // type the address manually.
        }
    }

    /// Returns the human-readable names of the required delivery fields that
    /// are missing, or nil if the address is complete.
    private func missingDeliveryFields() -> [String]? {
        func empty(_ value: String) -> Bool {
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        var missing: [String] = []
        if empty(line1) { missing.append("dirección") }
        if empty(city) { missing.append("ciudad") }
        if empty(state) { missing.append("estado") }
        if empty(zip) { missing.append("código postal") }
        return missing.isEmpty ? nil : missing
    }

    private func buildAddress() -> ShippingAddress? {
        func clean(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        let l1 = clean(line1)
        let l2 = clean(line2)
        let nb = clean(neighborhood)
        let c = clean(city)
        let st = clean(state)
        let z = clean(zip)
        let co = clean(country)
        let refs = clean(references)
        if l1 == nil, l2 == nil, nb == nil, c == nil, st == nil, z == nil, co == nil, refs == nil {
            return nil
        }
        return ShippingAddress(
            line1: l1,
            line2: l2,
            neighborhood: nb,
            city: c,
            state: st,
            zip: z,
            country: co,
            references: refs
        )
    }

    private func dismissAndClear() {
        dismiss()
    }
}

private struct SuccessView: View {
    let order: CreatedOrder
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text(order.orderNumber)
                .font(.title2.bold())

            LabeledContent("Estado") {
                Text(order.status.displayName)
            }
            LabeledContent("Total") {
                Text(order.total.formatted()).bold()
            }

            Spacer()

            Button(action: onClose) {
                Text("Listo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}
