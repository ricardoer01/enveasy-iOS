//
//  OrderDetailView.swift
//  inveasy
//

import SwiftUI

struct OrderDetailView: View {
    @Environment(AppState.self) private var app
    let orderId: UUID
    /// Optional reference to the parent list store, so a cancel here can
    /// patch the row shown in the previous screen without a full refetch.
    let ordersStore: OrdersStore?

    @State private var order: Order?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingCancelAlert = false
    @State private var cancelReason = ""
    @State private var isCancelling = false

    init(orderId: UUID, ordersStore: OrdersStore? = nil) {
        self.orderId = orderId
        self.ordersStore = ordersStore
    }

    var body: some View {
        ScrollView {
            if let order {
                content(for: order)
            } else if isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if let errorMessage {
                ContentUnavailableView(
                    "No se pudo cargar",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                .padding(.top, 60)
            }
        }
        .navigationTitle(order?.orderNumber ?? "Pedido")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("¿Cancelar pedido?", isPresented: $showingCancelAlert) {
            TextField("Motivo (opcional)", text: $cancelReason)
            Button("Cancelar pedido", role: .destructive) {
                Task { await cancelOrder() }
            }
            Button("Atrás", role: .cancel) { }
        } message: {
            Text("El inventario se restaurará y el pedido pasará a estado cancelado.")
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(for order: Order) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            header(order)
            itemsSection(order.items)
            totalsSection(order)
            timelineSection(order)
            fulfillmentSection(order)
            if let notes = order.notes, !notes.isEmpty {
                notesSection(notes)
            }
            if let reason = order.cancellationReason, !reason.isEmpty {
                cancellationSection(reason)
            }
            if order.status.isCancellableByCustomer {
                cancelButton()
            }
        }
        .padding()
    }

    private func header(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(order.orderNumber)
                .font(.title2.bold())
            Text(order.placedAt.formatted(date: .complete, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                OrderStatusBadge(status: order.status)
                DeliveryTypeChip(type: order.deliveryType)
            }
        }
    }

    private func itemsSection(_ items: [OrderItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Productos (\(items.count))")
            ForEach(items) { item in
                OrderItemRow(item: item)
                if item.id != items.last?.id {
                    Divider()
                }
            }
        }
    }

    private func totalsSection(_ order: Order) -> some View {
        VStack(spacing: 8) {
            SectionHeader("Resumen")
            totalRow("Subtotal", order.subtotal)
            if order.tax.cents > 0 {
                totalRow("Impuestos", order.tax)
            }
            if order.discount.cents > 0 {
                totalRow("Descuento", order.discount)
            }
            Divider()
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text(order.total.formatted()).font(.headline)
            }
        }
    }

    private func totalRow(_ label: String, _ amount: Money) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(amount.formatted())
        }
        .foregroundStyle(.secondary)
        .font(.subheadline)
    }

    @ViewBuilder
    private func timelineSection(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Historial")
            TimelineEntry(label: "Pedido realizado", date: order.placedAt)
            if let date = order.confirmedAt {
                TimelineEntry(label: "Confirmado", date: date)
            }
            if let date = order.readyForPickupAt {
                TimelineEntry(label: "Listo para recoger", date: date)
            }
            if let date = order.shippedAt {
                TimelineEntry(label: "Enviado", date: date)
            }
            if let date = order.deliveredAt {
                TimelineEntry(label: "Entregado", date: date)
            }
            if let date = order.paidAt {
                TimelineEntry(label: "Pagado", date: date)
            }
            if let date = order.cancelledAt {
                TimelineEntry(label: "Cancelado", date: date, tone: .red)
            }
        }
    }

    @ViewBuilder
    private func fulfillmentSection(_ order: Order) -> some View {
        switch order.deliveryType {
        case .delivery:
            if let address = order.shippingAddress {
                addressSection(address)
            }
        case .pickup:
            pickupSection(order.pickupLocation)
        }
    }

    private func pickupSection(_ location: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Recogida en tienda")
            if let location, !location.isEmpty {
                Text(location)
                    .font(.subheadline)
            } else {
                Text("Sin sucursal especificada")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addressSection(_ address: ShippingAddress) -> some View {
        // Prefer the new `line1`/`line2` keys; fall back to the legacy
        // `street`/`street2` ones for orders that haven't been re-written.
        let primary = address.line1 ?? address.street
        let secondary = address.line2 ?? address.street2

        return VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Envío")
            if let primary {
                if let secondary, !secondary.isEmpty {
                    Text("\(primary), \(secondary)")
                } else {
                    Text(primary)
                }
            }
            if let neighborhood = address.neighborhood {
                Text(neighborhood)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                if let city = address.city { Text(city) }
                if let state = address.state { Text(state) }
                if let zip = address.zip { Text("CP \(zip)") }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if let country = address.country, !country.isEmpty {
                Text(country)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let references = address.references, !references.isEmpty {
                Text("Referencias: \(references)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Notas")
            Text(notes)
                .font(.subheadline)
        }
    }

    private func cancellationSection(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Motivo de cancelación")
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func cancelButton() -> some View {
        Button(role: .destructive) {
            cancelReason = ""
            showingCancelAlert = true
        } label: {
            HStack {
                Spacer()
                if isCancelling {
                    ProgressView()
                } else {
                    Text("Cancelar pedido").bold()
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isCancelling)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func load() async {
        guard order == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let service = OrderService(client: app.client)
            order = try await service.order(id: orderId)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelOrder() async {
        let reason = cancelReason.trimmingCharacters(in: .whitespacesAndNewlines)
        isCancelling = true
        defer { isCancelling = false }
        do {
            let service = OrderService(client: app.client)
            _ = try await service.cancel(id: orderId, reason: reason.isEmpty ? nil : reason)
            // Refetch for cancelledAt / cancellationReason
            order = try await service.order(id: orderId)
            ordersStore?.updateStatus(of: orderId, to: .cancelled)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Subviews

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct OrderItemRow: View {
    let item: OrderItem

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName).font(.subheadline)
                Text("SKU \(item.productSku)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(formattedQuantity) \(item.unit.displayName) × \(item.unitPrice.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(item.subtotal.formatted())
                .font(.subheadline.bold())
        }
        .padding(.vertical, 4)
    }

    private var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter.string(from: item.quantity as NSDecimalNumber) ?? "\(item.quantity)"
    }
}

private struct TimelineEntry: View {
    enum Tone { case neutral, red }

    let label: String
    let date: Date
    var tone: Tone = .neutral

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tone == .red ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(tone == .red ? .red : .green)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.subheadline)
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
