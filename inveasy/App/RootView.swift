//
//  RootView.swift
//  inveasy
//

import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.auth {
        case .bootstrapping:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await app.bootstrap() }
        case .signedOut:
            AuthView()
        case .signedIn:
            providerGate
        }
    }

    @ViewBuilder
    private var providerGate: some View {
        switch app.providers.state {
        case .idle, .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await app.providers.bootstrap() }
        case .selecting(let providers):
            ProviderPickerView(providers: providers) { provider in
                await app.providers.select(provider)
            }
        case .selected:
            MainTabView()
        case .failed(let message):
            ProviderLoadFailureView(message: message) {
                Task { await app.providers.bootstrap() }
            }
        }
    }
}

private struct ProviderLoadFailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No se pudieron cargar los proveedores", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Reintentar", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
    }
}
