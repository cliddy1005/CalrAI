import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var username = ""
    @State private var pin = ""
    @State private var showError = false
    @State private var showCreateAccount = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // App branding
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                Text("CalrAI")
                    .font(.largeTitle.bold())
                Text("Smart Nutrition Tracking")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Login form
                VStack(spacing: 12) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("PIN", text: $pin)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .keyboardType(.numberPad)

                    Button {
                        if !auth.login(username: username, pin: pin) {
                            showError = true
                        }
                    } label: {
                        Text("Log In")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || pin.isEmpty)
                }
                .padding(.horizontal, 32)

                // Secondary actions
                VStack(spacing: 8) {
                    Button("Create Account") {
                        showCreateAccount = true
                    }

                    Button {
                        auth.continueOffline()
                    } label: {
                        Text("Continue Offline")
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .alert("Login Failed", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Invalid username or PIN. Please try again.")
            }
            .sheet(isPresented: $showCreateAccount) {
                CreateAccountView()
            }
        }
    }
}

struct CreateAccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("PIN (4+ digits)", text: $pin)
                        .textContentType(.newPassword)
                        .keyboardType(.numberPad)

                    SecureField("Confirm PIN", text: $confirmPin)
                        .textContentType(.newPassword)
                        .keyboardType(.numberPad)
                }

                Section {
                    Text("Your account is stored locally on this device. No internet required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createAccount() }
                        .disabled(!isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isValid: Bool {
        !username.isEmpty && pin.count >= 4 && pin == confirmPin
    }

    private func createAccount() {
        guard pin == confirmPin else {
            errorMessage = "PINs do not match."
            showError = true
            return
        }
        guard pin.count >= 4 else {
            errorMessage = "PIN must be at least 4 digits."
            showError = true
            return
        }
        if auth.createAccount(username: username, pin: pin) {
            dismiss()
        } else {
            errorMessage = "Username already taken."
            showError = true
        }
    }
}
