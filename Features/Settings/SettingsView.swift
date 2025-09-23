import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State var profile: UserProfile
    var onSave: (UserProfile) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal") {
                    Picker("Sex", selection: $profile.sex) {
                        ForEach(UserProfile.Sex.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Stepper("Age: \(profile.age)", value: $profile.age, in: 10 ... 80)
                    Stepper("Height: \(profile.heightCm) cm", value: $profile.heightCm, in: 120 ... 220)
                    Stepper("Weight: \(profile.weightKg) kg", value: $profile.weightKg, in: 30 ... 250)
                }
                Section("Lifestyle") {
                    Picker("Activity", selection: $profile.activity) {
                        ForEach(UserProfile.Activity.allCases) { Text($0.rawValue.capitalized).tag($0) }
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
            }
            .navigationTitle("Your profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(profile); dismiss() } }
                ToolbarItem(placement: .cancellationAction)  { Button("Cancel", role: .cancel) { dismiss() } }
            }
        }
    }
}
