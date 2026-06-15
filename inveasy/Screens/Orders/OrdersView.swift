//
//  OrdersView.swift
//  inveasy
//

import SwiftUI

struct OrdersView: View {
    @State private var store: OrdersStore

    init(client: APIClient) {
        _store = State(initialValue: OrdersStore(service: OrderService(client: client)))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pedidos")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable { await store.reload() }
                .task { await store.loadInitial() }
                .navigationDestination(for: UUID.self) { id in
                    OrderDetailView(orderId: id, ordersStore: store)
                }
                .alert("Error", isPresented: errorAlertBinding) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(store.errorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoadingPage && store.orders.isEmpty {
            ProgressView()
                .controlSize(.large)
        } else if store.orders.isEmpty {
            ContentUnavailableView(
                "Aún no tienes pedidos",
                systemImage: "list.bullet.rectangle",
                description: Text("Cuando realices un pedido aparecerá aquí.")
            )
        } else {
            List {
                ForEach(store.orders) { order in
                    NavigationLink(value: order.id) {
                        OrderRow(order: order)
                    }
                    .task {
                        if order.id == store.orders.last?.id {
                            await store.loadNextPage()
                        }
                    }
                }

                if store.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

// MARK: - Row

private struct OrderRow: View {
    let order: OrderSummary

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(order.orderNumber)
                    .font(.headline)
                Text(order.placedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    OrderStatusBadge(status: order.status)
                    DeliveryTypeChip(type: order.deliveryType)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(order.total.formatted())
                    .font(.subheadline.bold())
                Text("\(order.itemCount) art.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
