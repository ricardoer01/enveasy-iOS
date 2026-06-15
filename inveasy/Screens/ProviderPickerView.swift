//
//  ProviderPickerView.swift
//  inveasy
//

import SwiftUI

/// Full-screen provider picker shown after auth when more than one provider
/// is returned by the hub and there is no valid cached selection.
struct ProviderPickerView: View {
    let providers: [Provider]
    let onSelect: (Provider) async -> Void

    @State private var pendingId: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(providers) { provider in
                        Button {
                            tap(provider)
                        } label: {
                            ProviderRow(
                                provider: provider,
                                isPending: pendingId == provider.id
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(pendingId != nil)
                    }
                } header: {
                    Text("Selecciona un proveedor")
                } footer: {
                    Text("Puedes cambiar de proveedor más tarde desde Cuenta.")
                }
            }
            .navigationTitle("Proveedores")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func tap(_ provider: Provider) {
        guard pendingId == nil else { return }
        pendingId = provider.id
        Task { @MainActor in
            await onSelect(provider)
            pendingId = nil
        }
    }
}

private struct ProviderRow: View {
    let provider: Provider
    let isPending: Bool

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: provider.logoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Image(systemName: "building.2")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.headline)
                if let description = provider.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if isPending {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
