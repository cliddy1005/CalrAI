import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var env
    @EnvironmentObject private var auth: AuthManager
    @State var profile: UserProfile
    @State private var showResetConfirm = false
    var onSave: (UserProfile) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let username = auth.currentUsername {
                        HStack {
                            Text("Logged in as")
                            Spacer()
                            Text(username).foregroundStyle(.secondary)
                        }
                    } else if auth.isGuest {
                        HStack {
                            Image(systemName: "wifi.slash").foregroundStyle(.orange)
                            Text("Offline Mode").foregroundStyle(.secondary)
                        }
                    }
                    Button("Log Out", role: .destructive) {
                        auth.logout()
                        dismiss()
                    }
                }

                Section("Personal") {
                    Picker("Sex", selection: $profile.sex) {
                        ForEach(UserProfile.Sex.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Stepper("Age: \(profile.age)",        value: $profile.age,      in: 10...80)
                    Stepper("Height: \(profile.heightCm) cm", value: $profile.heightCm, in: 120...220)
                    Stepper("Weight: \(profile.weightKg) kg", value: $profile.weightKg, in: 30...250)
                }

                Section("Lifestyle") {
                    Picker("Activity", selection: $profile.activity) {
                        ForEach(UserProfile.Activity.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Goal", selection: $profile.goal) {
                        ForEach(UserProfile.Goal.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }

                let t = profile.macroTargets()
                Section("Targets") {
                    Text("Energy  \(Int(t.kcal)) kcal")
                    Text("Protein \(Int(t.p)) g")
                    Text("Fat     \(Int(t.f)) g")
                    Text("Carbs   \(Int(t.c)) g")
                }

                Section("Data") {
                    Button("Reset Local Database", role: .destructive) {
                        showResetConfirm = true
                    }
                }
            }
            .navigationTitle("Your Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(profile); dismiss() } }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
            }
            .confirmationDialog("Reset all data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset Database", role: .destructive) {
                    env.localStore.deleteAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all cached foods and diary entries.")
            }
        }
    }
}
