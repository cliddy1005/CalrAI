import SwiftUI

/// View for creating a custom food entry when offline and food is not found.
struct CustomFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var env

    var barcode: String?
    var onSave: (Product) -> Void

    @State private var name = ""
    @State private var kcalPer100g = ""
    @State private var proteinPer100g = ""
    @State private var fatPer100g = ""
    @State private var carbPer100g = ""
    @State private var servingSize = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Food Details") {
                    TextField("Food name", text: $name)
                    if let barcode {
                        HStack {
                            Text("Barcode")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(barcode)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Nutrition per 100g") {
                    HStack {
                        Text("Calories (kcal)")
                        TextField("0", text: $kcalPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein (g)")
                        TextField("0", text: $proteinPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fat (g)")
                        TextField("0", text: $fatPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Carbs (g)")
                        TextField("0", text: $carbPer100g)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Serving (optional)") {
                    HStack {
                        Text("Serving size (g)")
                        TextField("e.g. 30", text: $servingSize)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Custom Food")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || Double(kcalPer100g) == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private func save() {
        let product = Product(
            barcode: barcode ?? UUID().uuidString,
            name: name,
            kcalPer100g: Double(kcalPer100g) ?? 0,
            proteinPer100g: Double(proteinPer100g),
            fatPer100g: Double(fatPer100g),
            carbPer100g: Double(carbPer100g),
            servingSizeGrams: Double(servingSize),
            nutriScore: nil
        )

        // Cache the custom food locally
        Task {
            try? await env.foodRepository.save(food: product)
        }

        onSave(product)
        dismiss()
    }
}
