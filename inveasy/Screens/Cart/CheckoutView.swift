//
//  CheckoutView.swift
//  inveasy
//

import SwiftUI

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
                                TextField("Interior / Depto. (opcional)", text: $line2)
                                    .textContentType(.streetAddressLine2)
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
                                TextField("Referencias (opcional)", text: $references, axis: .vertical)
                                    .lineLimit(2...4)
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
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
