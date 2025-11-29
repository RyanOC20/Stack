import SwiftUI

struct AuthFlowView: View {
    enum Step {
        case welcome
        case createAccount
        case logIn
    }

    @Binding var isAuthenticated: Bool
    @State private var step: Step = .welcome
    @State private var emailOrPhone: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ColorPalette.background
                .ignoresSafeArea()

            content
                .padding(Spacing.contentPadding)
                .frame(maxWidth: 520)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            welcomeView
        case .createAccount:
            createAccountView
        case .logIn:
            logInView
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 16) {
                appIcon
                    .resizable()
                    .environment(\.displayScale, 2)
                    .scaledToFit()
                    .frame(width: 400, height: 400)
            }

            VStack(spacing: 12) {
                primaryButton(title: "Create Account") {
                    step = .createAccount
                    resetErrors()
                }

                secondaryButton(title: "Log In") {
                    step = .logIn
                    resetErrors()
                }
            }

            Spacer()
        }
    }

    private var createAccountView: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("Create Account")
                .font(Typography.assignmentName)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                authTextField("Email or phone number", text: $emailOrPhone)
                authSecureField("Password", text: $password)
                authSecureField("Confirm password", text: $confirmPassword)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.secondary)
                    .foregroundColor(.white)
            }

            primaryButton(title: "Create Account") {
                submitCreateAccount()
            }

            secondaryButton(title: "Back") {
                step = .welcome
                resetForm()
            }
        }
    }

    private var logInView: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("Log In")
                .font(Typography.assignmentName)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                authTextField("Email or phone number", text: $emailOrPhone)
                authSecureField("Password", text: $password)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.secondary)
                    .foregroundColor(.white)
            }

            primaryButton(title: "Log In") {
                submitLogIn()
            }

            secondaryButton(title: "Back") {
                step = .welcome
                resetForm()
            }
        }
    }

    private func authTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(Typography.body)
            .textFieldStyle(.plain)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: 320)
            .background(ColorPalette.rowHover)
    }

    private func authSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .font(Typography.body)
            .textFieldStyle(.plain)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: 320)
            .background(ColorPalette.rowHover)
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.assignmentName)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(ColorPalette.rowSelection)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 260)
        .contentShape(Rectangle())
    }

    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.assignmentName)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 260)
        .contentShape(Rectangle())
    }

    private func submitCreateAccount() {
        resetErrors()
        guard !emailOrPhone.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords must match."
            return
        }

        isAuthenticated = true
    }

    private func submitLogIn() {
        resetErrors()
        guard !emailOrPhone.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }

        isAuthenticated = true
    }

    private func resetForm() {
        emailOrPhone = ""
        password = ""
        confirmPassword = ""
        resetErrors()
    }

    private func resetErrors() {
        errorMessage = nil
    }

    private var appIcon: Image {
        Image("Large")
    }
}
