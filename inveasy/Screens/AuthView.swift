//
//  AuthView.swift
//  inveasy
//

import SwiftUI

struct AuthView: View {

    enum Mode: Hashable {
        case login, register
    }

    @State private var mode: Mode = .login

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Modo", selection: $mode) {
                    Text("Iniciar sesión").tag(Mode.login)
                    Text("Crear cuenta").tag(Mode.register)
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    switch mode {
                    case .login: LoginForm()
                    case .register: RegisterForm()
                    }
                }
            }
            .navigationTitle("Inveasy")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Login

private struct LoginForm: View {
    @Environment(AppState.self) private var app

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && !isSubmitting
    }

    var body: some View {
        Form {
            Section("Datos") {
                TextField("Correo", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Contraseña", text: $password)
                    .textContentType(.password)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Iniciar sesión").bold()
                        }
                        Spacer()
                    }
                }
                .disabled(!canSubmit)
            }
        }
    }

    private func submit() {
        Task { @MainActor in
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                try await app.signIn(email: email, password: password)
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Register

private struct RegisterForm: View {
    @Environment(AppState.self) private var app

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var phone = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@")
            && password.count >= 8
            && !phone.trimmingCharacters(in: .whitespaces).isEmpty
            && !isSubmitting
    }

    var body: some View {
        Form {
            Section("Datos") {
                TextField("Nombre completo", text: $name)
                    .textContentType(.name)
                    .autocorrectionDisabled()

                TextField("Correo", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Contraseña (mín. 8)", text: $password)
                    .textContentType(.newPassword)

                TextField("Teléfono", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Crear cuenta").bold()
                        }
                        Spacer()
                    }
                }
                .disabled(!canSubmit)
            }
        }
    }

    private func submit() {
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        Task { @MainActor in
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                try await app.register(
                    name: name.trimmingCharacters(in: .whitespaces),
                    email: email,
                    password: password,
                    phone: trimmedPhone
                )
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
