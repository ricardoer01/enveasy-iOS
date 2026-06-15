//
//  OrderStatusBadge.swift
//  inveasy
//

import SwiftUI

struct OrderStatusBadge: View {
    let status: OrderStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .pending:    return .orange
        case .confirmed:  return .blue
        case .processing: return .indigo
        case .ready:      return .teal
        case .shipped:    return .purple
        case .delivered:  return .green
        case .paid:       return .green
        case .cancelled:  return .red
        }
    }
}

struct DeliveryTypeChip: View {
    let type: DeliveryType

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.gray.opacity(0.15)))
            .foregroundStyle(.secondary)
    }

    private var label: String {
        switch type {
        case .pickup:   return "Recoger"
        case .delivery: return "Envío"
        }
    }

    private var icon: String {
        switch type {
        case .pickup:   return "bag"
        case .delivery: return "shippingbox"
        }
    }
}
