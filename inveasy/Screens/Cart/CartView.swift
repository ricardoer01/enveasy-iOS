//
//  CartView.swift
//  inveasy
//

import SwiftUI

struct CartView: View {
    @Environment(CartStore.self) private var cart
    @State private var showingCheckout = false

    var body: some View {
        NavigationStack {
            Group {
                if cart.isEmpty {
                    ContentUnavailableView(
                        "Tu carrito está vacío",
                        systemImage: "cart",
                        description: Text("Agrega productos desde el catálogo.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(cart.lines) { line in
                                CartLineRow(line: line)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    cart.remove(cart.lines[index].id)
                                }
                            }
                        }

                        Section {
                            LabeledContent("Subtotal") {
                                Text(cart.subtotal.formatted()).bold()
                            }
                            Text("Impuestos y descuentos se calculan al confirmar el pedido.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Section {
                            Button {
                                showingCheckout = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Realizar pedido").bold()
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Carrito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !cart.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            cart.clear()
                        } label: {
                            Text("Vaciar")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCheckout) {
                CheckoutView()
            }
        }
    }
}

// MARK: - Row

private struct CartLineRow: View {
    @Environment(CartStore.self) private var cart
    let line: CartLine

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(url: line.imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "photo")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(line.productName)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(line.unitPrice.formatted())
                    Text("/ \(line.unit.displayName)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                HStack {
                    Stepper(
                        value: quantityBinding,
                        in: 1...9_999,
                        step: 1
                    ) {
                        Text("Cantidad: \(formatted(line.quantity))")
                            .font(.caption)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(line.subtotal.formatted())
                .font(.subheadline.bold())
        }
        .padding(.vertical, 4)
    }

    private var quantityBinding: Binding<Decimal> {
        Binding(
            get: { line.quantity },
            set: { cart.setQuantity($0, for: line.id) }
        )
    }

    private func formatted(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
