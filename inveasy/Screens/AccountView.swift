//
//  AccountView.swift
//  inveasy
//

import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var app
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @State private var isSigningOut = false

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
                        Button("Cambiar proveedor") {
                            Task { await app.providers.clearSelection() }
                        }
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
        }
    }

    private func signOut() {
        Task { @MainActor in
            isSigningOut = true
            await app.signOut()
            isSigningOut = false
        }
    }
}
