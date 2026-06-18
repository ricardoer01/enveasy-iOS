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

/// Horizontal chip strip without `ScrollView`. iOS 26's `ScrollView(.horizontal)`
/// was leaking vertical/diagonal pans into the chip row after a NavigationStack
/// rebuild (e.g. provider switch), and no combination of `.contentMargins`,
/// `.safeAreaInset`, `.scrollBounceBehavior(axes:)`, or `.simultaneousGesture`
/// reliably contained it. Rolling the pan by hand removes the entire scroll
/// subsystem — the `DragGesture` only ever writes the horizontal component of
/// `translation`, so vertical motion is structurally impossible.
private struct CategoryChips: View {
    let store: CatalogStore

    @State private var offset: CGFloat = 0
    @State private var dragBaseOffset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let maxScroll = max(0, contentWidth - geo.size.width)
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
            // Pin the HStack to its natural horizontal size so the
            // background `GeometryReader` measures the real content width
            // — not whatever width the outer container would otherwise
            // propose. Without this the measurement collapses to
            // `geo.size.width` and `maxScroll` is always zero.
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contentWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, new in
                            contentWidth = new
                            // Re-clamp if content shrank past current offset.
                            let clamped = max(min(offset, 0), -max(0, new - geo.size.width))
                            if clamped != offset {
                                offset = clamped
                                dragBaseOffset = clamped
                            }
                        }
                }
            )
            .frame(height: 48)
            .offset(x: offset)
            // Flexible outer container provides the hit-test surface for
            // the gesture; the HStack inside keeps its natural width and
            // is leading-aligned. Visual overflow is clipped by the outer
            // `.clipped()` on the GeometryReader's frame.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        // Only the horizontal component is ever consulted.
                        // The vertical component is dropped on the floor.
                        // Interpolate toward the finger with an interactive
                        // spring so the strip glides continuously during
                        // the drag instead of snapping 1:1 — gives it a
                        // subtle trailing inertia like a native scroll.
                        let proposed = dragBaseOffset + value.translation.width
                        let target = max(min(proposed, 0), -maxScroll)
                        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.82, blendDuration: 0.1)) {
                            offset = target
                        }
                    }
                    .onEnded { value in
                        // Project where the finger would have ended up if
                        // it kept its release velocity through natural
                        // deceleration, then spring-animate to that point.
                        // Gives the strip the same glide-to-stop feel as a
                        // native ScrollView without re-introducing one.
                        // Amplify SwiftUI's conservative projection so a
                        // flick carries the strip a bit further, and use a
                        // longer spring response for the glide-out.
                        let projected = value.predictedEndTranslation.width * 1.4
                        let predicted = dragBaseOffset + projected
                        let target = max(min(predicted, 0), -maxScroll)
                        withAnimation(.spring(response: 0.85, dampingFraction: 0.85)) {
                            offset = target
                        }
                        dragBaseOffset = target
                    }
            )
        }
        .frame(height: 48)
        .clipped()
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
