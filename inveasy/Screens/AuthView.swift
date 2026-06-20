//
//  AuthView.swift
//  inveasy
//

import SwiftUI

struct AuthView: View {

    enum Mode: Hashable {
        case login, register
    }

    struct PendingVerification: Equatable {
        let customerID: UUID
        let email: String
    }

    @State private var mode: Mode = .login
    /// Set after a successful `/auth/register`. While non-nil the screen
    /// hides the login/register forms and shows the code-entry step.
    @State private var pendingVerification: PendingVerification?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                BrandHero()
                    .padding(.top, 32)

                if let pending = pendingVerification {
                    VerifyForm(
                        customerID: pending.customerID,
                        email: pending.email,
                        onBack: { pendingVerification = nil }
                    )
                    .padding(.horizontal)
                } else {
                    Picker("Modo", selection: $mode) {
                        Text("Iniciar sesión").tag(Mode.login)
                        Text("Crear cuenta").tag(Mode.register)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Group {
                        switch mode {
                        case .login:
                            LoginForm()
                        case .register:
                            RegisterForm(onCodeSent: { customerID, email in
                                pendingVerification = PendingVerification(
                                    customerID: customerID,
                                    email: email
                                )
                            })
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Brand hero

private struct BrandHero: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bag.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.blue.opacity(0.3), radius: 10, y: 6)

            Text("Bienvenido a Inveasy")
                .font(.title2.weight(.bold))

            Text("Compra a domicilio en tus tiendas favoritas")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Field styling

private struct AuthFieldChrome<Content: View>: View {
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PasswordField: View {
    let title: String
    @Binding var text: String
    var textContentType: UITextContentType = .password
    @State private var isRevealed = false

    var body: some View {
        AuthFieldChrome(icon: "lock") {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(title, text: $text)
                        .textContentType(textContentType)
                }
            }
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Login

private struct LoginForm: View {
    @Environment(AppState.self) private var app

    private enum Field: Hashable { case email, password }
    @FocusState private var focusedField: Field?

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                AuthFieldChrome(icon: "envelope") {
                    TextField("Correo", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .onChange(of: email) { _, _ in errorMessage = nil }
                }

                PasswordField(title: "Contraseña", text: $password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .onChange(of: password) { _, _ in errorMessage = nil }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: submit) {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Iniciar sesión").bold()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)
        }
        .onAppear { focusedField = .email }
    }

    private func submit() {
        guard canSubmit else { return }
        Task { @MainActor in
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                try await app.signIn(email: email, password: password)
            } catch let error as APIError {
                errorMessage = error.errorDescription
                Haptics.notify(.error)
            } catch {
                errorMessage = error.localizedDescription
                Haptics.notify(.error)
            }
        }
    }
}

// MARK: - Register

private struct RegisterForm: View {
    @Environment(AppState.self) private var app

    /// Invoked after `/auth/register` succeeds, handing the parent the
    /// `customerId` and the email needed for the verification step.
    let onCodeSent: (_ customerID: UUID, _ email: String) -> Void

    private enum Field: Hashable { case name, email, password, phone }
    @FocusState private var focusedField: Field?

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
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                AuthFieldChrome(icon: "person") {
                    TextField("Nombre completo", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                        .onChange(of: name) { _, _ in errorMessage = nil }
                }

                AuthFieldChrome(icon: "envelope") {
                    TextField("Correo", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .onChange(of: email) { _, _ in errorMessage = nil }
                }

                PasswordField(title: "Contraseña (mín. 8)", text: $password, textContentType: .newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .phone }
                    .onChange(of: password) { _, _ in errorMessage = nil }

                AuthFieldChrome(icon: "phone") {
                    TextField("Teléfono", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($focusedField, equals: .phone)
                        .submitLabel(.go)
                        .onSubmit(submit)
                        .onChange(of: phone) { _, _ in errorMessage = nil }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: submit) {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Crear cuenta").bold()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)
        }
        .onAppear { focusedField = .name }
    }

    private func submit() {
        guard canSubmit else { return }
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        Task { @MainActor in
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                let customerID = try await app.register(
                    name: trimmedName,
                    email: trimmedEmail,
                    password: password,
                    phone: trimmedPhone
                )
                Haptics.notify(.success)
                onCodeSent(customerID, trimmedEmail)
            } catch let error as APIError {
                errorMessage = error.errorDescription
                Haptics.notify(.error)
            } catch {
                errorMessage = error.localizedDescription
                Haptics.notify(.error)
            }
        }
    }
}

// MARK: - Verify email

private struct VerifyForm: View {
    @Environment(AppState.self) private var app

    let customerID: UUID
    let email: String
    let onBack: () -> Void

    @FocusState private var isCodeFocused: Bool
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        code.count == 6 && code.allSatisfy(\.isNumber) && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Verifica tu correo")
                    .font(.title3.weight(.semibold))
                Text("Te enviamos un código de 6 dígitos a")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(email)
                    .font(.subheadline.weight(.semibold))
            }

            AuthFieldChrome(icon: "key") {
                TextField("Código de 6 dígitos", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isCodeFocused)
                    .onChange(of: code) { _, newValue in
                        // Strip non-digits and cap length to 6 — the
                        // number-pad keyboard already filters most of
                        // this, but pasted values may include letters.
                        let digits = newValue.filter(\.isNumber)
                        let trimmed = String(digits.prefix(6))
                        if trimmed != newValue { code = trimmed }
                        errorMessage = nil
                    }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: submit) {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Verificar").bold()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)

            Button("Cambiar correo", action: onBack)
                .font(.footnote)
                .disabled(isSubmitting)
        }
        .onAppear { isCodeFocused = true }
    }

    private func submit() {
        guard canSubmit else { return }
        Task { @MainActor in
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                try await app.verifyEmail(customerID: customerID, code: code)
                Haptics.notify(.success)
                // Success transitions auth state to `.signedIn`, which
                // pops this whole view via RootView.
            } catch let error as APIError {
                errorMessage = error.errorDescription
                Haptics.notify(.error)
            } catch {
                errorMessage = error.localizedDescription
                Haptics.notify(.error)
            }
        }
    }
}
