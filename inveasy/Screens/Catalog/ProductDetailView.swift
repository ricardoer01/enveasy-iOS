//
//  ProductDetailView.swift
//  inveasy
//

import SwiftUI

struct ProductDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(CartStore.self) private var cart
    let productId: UUID

    @State private var product: Product?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didAdd = false

    var body: some View {
        ScrollView {
            if let product {
                content(for: product)
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
        .navigationTitle(product?.name ?? "Producto")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func content(for product: Product) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CachedAsyncImage(url: product.imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Image(systemName: "photo")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: 240)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(product.name)
                        .font(.title2.bold())
                    Text("SKU \(product.sku)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(product.price.formatted())
                        .font(.title.bold())
                    Text("/ \(product.unit.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                StockBadge(product: product)

                if let descriptionLong = product.descriptionLong, !descriptionLong.isEmpty {
                    Divider()
                    Text(descriptionLong)
                        .font(.body)
                } else if let description = product.description, !description.isEmpty {
                    Divider()
                    Text(description)
                        .font(.body)
                }

                Button {
                    cart.add(product: product)
                    didAdd = true
                } label: {
                    Label(
                        didAdd ? "Agregado" : "Agregar al carrito",
                        systemImage: didAdd ? "checkmark" : "cart.badge.plus"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!product.isInStock)
                .padding(.top, 8)
                .animation(.default, value: didAdd)
            }
            .padding(.horizontal)
        }
    }

    private func load() async {
        guard product == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let service = CatalogService(client: app.client)
            product = try await service.product(id: productId)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct StockBadge: View {
    let product: Product

    var body: some View {
        if product.isInStock {
            Label("En existencia", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        } else {
            Label("Agotado", systemImage: "xmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }
}
