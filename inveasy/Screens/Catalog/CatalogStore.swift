//
//  CatalogStore.swift
//  inveasy
//

import Foundation
import Observation

/// View state for the Catálogo tab.
///
/// Owns the category list, the current products page, and the active filters
/// (search text + selected category). Pagination is page-based to match the
/// API (`page` / `per_page` / `total_pages`); the store appends additional
/// pages onto `products` and exposes `canLoadMore` for the grid to trigger.
@MainActor
@Observable
final class CatalogStore {
    private let service: CatalogService

    // MARK: - Loaded data
    private(set) var categories: [Category] = []
    private(set) var products: [Product] = []

    // MARK: - Filters
    var selectedCategoryId: UUID?
    private(set) var search: String = ""

    // MARK: - Loading / error state
    private(set) var isLoadingPage = false
    private(set) var isLoadingMore = false
    private(set) var isLoadingCategories = false
    var errorMessage: String?

    // MARK: - Pagination cursor
    private var nextPage = 1
    private var totalPages = 1
    private let perPage = 20

    // MARK: - Debounce
    private var searchDebounceTask: Task<Void, Never>?
    private let searchDebounce: Duration = .milliseconds(400)

    var canLoadMore: Bool {
        !isLoadingMore && !isLoadingPage && nextPage <= totalPages
    }

    init(service: CatalogService) {
        self.service = service
    }

    func loadInitial() async {
        if categories.isEmpty {
            await loadCategories()
        }
        if products.isEmpty {
            await reloadProducts()
        }
    }

    func loadCategories() async {
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        do {
            categories = try await service.categories()
        } catch {
            apply(error)
        }
    }

    /// Reset pagination and reload the first page using current filters.
    func reloadProducts() async {
        isLoadingPage = true
        nextPage = 1
        totalPages = 1
        defer { isLoadingPage = false }

        do {
            let result = try await service.products(
                search: search.isEmpty ? nil : search,
                categoryId: selectedCategoryId,
                page: nextPage,
                perPage: perPage
            )
            products = result.items
            totalPages = result.meta.totalPages
            nextPage += 1
            errorMessage = nil
        } catch {
            apply(error)
        }
    }

    func loadNextPage() async {
        guard canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let result = try await service.products(
                search: search.isEmpty ? nil : search,
                categoryId: selectedCategoryId,
                page: nextPage,
                perPage: perPage
            )
            products.append(contentsOf: result.items)
            totalPages = result.meta.totalPages
            nextPage += 1
        } catch {
            apply(error)
        }
    }

    func selectCategory(_ id: UUID?) async {
        guard selectedCategoryId != id else { return }
        selectedCategoryId = id
        searchDebounceTask?.cancel()
        await reloadProducts()
    }

    /// Update the search term and schedule a debounced reload. Successive
    /// keystrokes within the debounce window collapse into a single request.
    func setSearch(_ query: String) {
        guard query != search else { return }
        search = query
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: self.searchDebounce)
            } catch {
                return
            }
            if Task.isCancelled { return }
            await self.reloadProducts()
        }
    }

    /// Fire the search immediately (e.g. on return-key submit), skipping the
    /// pending debounce.
    func submitSearch() async {
        searchDebounceTask?.cancel()
        await reloadProducts()
    }

    private func apply(_ error: Error) {
        // Cancellation is a normal signal (e.g. when a new debounced search
        // supersedes the in-flight one) — don't show it to the user.
        if error is CancellationError { return }
        if let api = error as? APIError {
            errorMessage = api.errorDescription
        } else {
            errorMessage = error.localizedDescription
        }
    }
}
