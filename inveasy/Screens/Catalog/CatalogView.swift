//
//  CatalogView.swift
//  inveasy
//

import SwiftUI

struct CatalogView: View {
    @Environment(AppState.self) private var app
    @State private var store: CatalogStore

    init(client: APIClient) {
        _store = State(initialValue: CatalogStore(service: CatalogService(client: client)))
    }

    var body: some View {
        NavigationStack {
            ProductsGrid(store: store)
                // Apply `.refreshable` BEFORE the chips' `.safeAreaInset`.
                // `.refreshable` writes a `RefreshAction` into the
                // `\.refresh` environment value, which propagates to every
                // descendant ScrollView. If applied after the inset, the
                // chips' inner ScrollView inherits it and installs a
                // pull-to-refresh recognizer — that recognizer is what
                // lets vertical pans drag the strip after a NavigationStack
                // rebuild. Scoping `.refreshable` to ProductsGrid only
                // keeps the recognizer off the chips.
                .refreshable {
                    await store.reloadProducts()
                }
                // Pin the chips above the products grid as a top safe-area
                // inset. This takes the chip strip OUT of the scrolling
                // content area, so it can't be coupled to the products
                // grid's scroll gesture or to the navigation bar's
                // search-drawer transitions.
                .safeAreaInset(edge: .top, spacing: 0) {
                    CategoryChips(store: store)
                        .background(.regularMaterial)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Provider name sits centered where a title would,
                    // styled smaller than a heading so it reads as
                    // context ("which store am I shopping in?") rather
                    // than a screen title.
                    if let providerName = app.providers.current?.name {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 0) {
                                Text("Comprando en")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(providerName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
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

    private static let allID = "all"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Chip(
                        label: "Todas",
                        isSelected: store.selectedCategoryId == nil
                    ) {
                        Task { await store.selectCategory(nil) }
                    }
                    .id(Self.allID)
                    ForEach(store.categories) { category in
                        Chip(
                            label: category.name,
                            isSelected: store.selectedCategoryId == category.id
                        ) {
                            Task { await store.selectCategory(category.id) }
                        }
                        .id(category.id.uuidString)
                    }
                }
                .padding(.horizontal)
            }
            
            .frame(height: 44)
            .clipped()
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            // Keep the selected chip visible. If the user picks one that's
            // off-screen — or returns to the tab with selection set — scroll
            // it into the center so it's always discoverable.
            .onChange(of: store.selectedCategoryId) { _, newId in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newId?.uuidString ?? Self.allID, anchor: .center)
                }
            }
        }
    }
}

private struct Chip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
            }
            .padding(.top, 10)
            .contentShape(Rectangle())
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
            .overlay(alignment: .topLeading) {
                if product.isLowStock {
                    Label("Bajo stock", systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange, in: Capsule())
                        .padding(8)
                }
            }

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
