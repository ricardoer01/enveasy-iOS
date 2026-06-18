//
//  CatalogView.swift
//  inveasy
//

import SwiftUI

struct CatalogView: View {
    @State private var store: CatalogStore

    init(client: APIClient) {
        _store = State(initialValue: CatalogStore(service: CatalogService(client: client)))
    }

    var body: some View {
        NavigationStack {
            ProductsGrid(store: store)
                // Pin the chips above the products grid as a top safe-area
                // inset. This takes the chip strip OUT of the scrolling
                // content area, so it can't be coupled to the products
                // grid's scroll gesture or to the navigation bar's
                // search-drawer transitions — which is what was leaking
                // vertical/diagonal pans into the chips after a provider
                // switch rebuilt the NavigationStack.
                .safeAreaInset(edge: .top, spacing: 0) {
                    CategoryChips(store: store)
                        .background(.bar)
                }
                .navigationTitle("Catálogo")
                .navigationBarTitleDisplayMode(.inline)
                // Pin the search bar so it stays visible regardless of
                // which ScrollView the system uses as the reveal trigger.
                .searchable(
                    text: searchBinding,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Buscar productos"
                )
                .onSubmit(of: .search) {
                    Task { await store.submitSearch() }
                }
                .refreshable {
                    await store.reloadProducts()
                }
                .alert("Error", isPresented: errorAlertBinding) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(store.errorMessage ?? "")
                }
                .task {
                    await store.loadInitial()
                }
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { store.search },
            set: { store.setSearch($0) }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

// MARK: - Category chips

private struct CategoryChips: View {
    let store: CatalogStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(
                    label: "Todas",
                    isSelected: store.selectedCategoryId == nil
                ) {
                    Task { await store.selectCategory(nil) }
                }
                ForEach(store.categories) { category in
                    Chip(
                        label: category.name,
                        isSelected: store.selectedCategoryId == category.id
                    ) {
                        Task { await store.selectCategory(category.id) }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 48)
        .clipped()
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct Chip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Product grid

private struct ProductsGrid: View {
    @Bindable var store: CatalogStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if store.isLoadingPage && store.products.isEmpty {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<6, id: \.self) { _ in
                        ProductCardSkeleton()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            } else if store.products.isEmpty {
                ContentUnavailableView(
                    "Sin resultados",
                    systemImage: "magnifyingglass",
                    description: Text("Intenta con otra búsqueda o categoría.")
                )
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(store.products.enumerated()), id: \.element.id) { index, product in
                        NavigationLink(value: product.id) {
                            ProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                        .task {
                            // Prefetch the next page when the user is within 5
                            // items of the end, so the next batch is ready by
                            // the time they scroll into it. `loadNextPage` is
                            // a no-op while a load is in flight or exhausted.
                            if index >= store.products.count - 5 {
                                await store.loadNextPage()
                            }
                        }
                    }
                }
                .padding(.horizontal)

                if store.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 12)
                }
            }
        }
        .navigationDestination(for: UUID.self) { productId in
            ProductDetailView(productId: productId)
        }
    }
}

// MARK: - Product card

private struct ProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: product.imageUrl) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .clipped()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(product.name)
                .font(.subheadline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline) {
                Text(product.price.formatted())
                    .font(.headline)
                Spacer()
                Text(product.unit.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.largeTitle)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
