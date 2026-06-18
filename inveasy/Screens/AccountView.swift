//
//  AccountView.swift
//  inveasy
//

import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var app
    @Environment(CartStore.self) private var cart
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @State private var isSigningOut = false
    @State private var showingSwitchProviderConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                if case .signedIn(let customer) = app.auth {
                    Section("Perfil") {
                        LabeledContent("Nombre", value: customer.name)
                        LabeledContent("Correo", value: customer.email)
                        if let phone = customer.phone, !phone.isEmpty {
                            LabeledContent("Teléfono", value: phone)
                        }
                    }
                }

                if let provider = app.providers.current {
                    Section("Proveedor") {
                        LabeledContent("Activo", value: provider.name)
                        Button("Cambiar proveedor", action: tapSwitchProvider)
                    }
                }

                Section("Apariencia") {
                    Picker("Tema", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(role: .destructive, action: signOut) {
                        HStack {
                            Spacer()
                            if isSigningOut {
                                ProgressView()
                            } else {
                                Text("Cerrar sesión")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("Cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Cambiar de proveedor vaciará tu carrito",
                isPresented: $showingSwitchProviderConfirmation,
                titleVisibility: .visible
            ) {
                Button("Vaciar y cambiar", role: .destructive) {
                    confirmSwitchProvider()
                }
                Button("Conservar carrito", role: .cancel) { }
            } message: {
                Text("Los productos del carrito pertenecen al proveedor actual y no estarán disponibles en otro.")
            }
        }
    }

    private func tapSwitchProvider() {
        if cart.isEmpty {
            Task { await app.providers.clearSelection() }
        } else {
            showingSwitchProviderConfirmation = true
        }
    }

    private func confirmSwitchProvider() {
        cart.clear()
        Task { await app.providers.clearSelection() }
    }

    private func signOut() {
        Task { @MainActor in
            isSigningOut = true
            await app.signOut()
            isSigningOut = false
        }
    }
}
