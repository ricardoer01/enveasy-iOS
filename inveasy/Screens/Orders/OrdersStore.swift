//
//  OrdersStore.swift
//  inveasy
//

import Foundation
import Observation

@MainActor
@Observable
final class OrdersStore {
    private let service: OrderService

    private(set) var orders: [OrderSummary] = []
    private(set) var isLoadingPage = false
    private(set) var isLoadingMore = false
    var errorMessage: String?

    private var nextPage = 1
    private var totalPages = 1
    private let perPage = 20

    init(service: OrderService) {
        self.service = service
    }

    var canLoadMore: Bool {
        !isLoadingMore && !isLoadingPage && nextPage <= totalPages
    }

    func loadInitial() async {
        if orders.isEmpty {
            await reload()
        }
    }

    func reload() async {
        isLoadingPage = true
        nextPage = 1
        totalPages = 1
        defer { isLoadingPage = false }

        do {
            let result = try await service.orders(page: nextPage, perPage: perPage)
            orders = result.items
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
            let result = try await service.orders(page: nextPage, perPage: perPage)
            orders.append(contentsOf: result.items)
            totalPages = result.meta.totalPages
            nextPage += 1
        } catch {
            apply(error)
        }
    }

    /// Patch the local list when a detail action changes status (e.g. cancel).
    /// The detail view fetches a full `Order`; we only need to update the row
    /// shape (`OrderSummary`) here.
    func updateStatus(of id: UUID, to status: OrderStatus) {
        guard let index = orders.firstIndex(where: { $0.id == id }) else { return }
        let existing = orders[index]
        orders[index] = OrderSummary(
            id: existing.id,
            orderNumber: existing.orderNumber,
            customerName: existing.customerName,
            customerEmail: existing.customerEmail,
            status: status,
            deliveryType: existing.deliveryType,
            total: existing.total,
            itemCount: existing.itemCount,
            placedAt: existing.placedAt
        )
    }

    private func apply(_ error: Error) {
        if error is CancellationError { return }
        if let api = error as? APIError {
            errorMessage = api.errorDescription
        } else {
            errorMessage = error.localizedDescription
        }
    }
}
