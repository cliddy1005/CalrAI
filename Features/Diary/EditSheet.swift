import SwiftUI

struct EditSheet: View {
    let entry: FoodEntry
    var save: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    enum Mode: String, CaseIterable, Identifiable { case grams, servings; var id: Self { self } }
    @State private var mode: Mode
    @State private var text: String

    init(entry: FoodEntry, save: @escaping (Double) -> Void) {
        self.entry = entry; self.save = save
        if let s = entry.product.servingSizeGrams {
            _mode = State(initialValue: .servings)
            _text = State(initialValue: String(format: "%.2f", entry.grams / s))
        } else {
            _mode = State(initialValue: .grams)
            _text = State(initialValue: String(Int(entry.grams)))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Unit", selection: $mode) {
                    Text("Grams").tag(Mode.grams)
                    if entry.product.servingSizeGrams != nil { Text("Servings").tag(Mode.servings) }
                }.pickerStyle(.segmented)
                TextField("Amount", text: $text).keyboardType(.decimalPad)
            }
            .navigationTitle("Edit")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit() }
                        .disabled(Double(text.replacingOccurrences(of: ",", with: ".")) == nil)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
            }
        }
    }
    private func commit() {
        guard var v = Double(text.replacingOccurrences(of: ",", with: ".")) else { return }
        if mode == .servings, let per = entry.product.servingSizeGrams { v *= per }
        save(max(1, v.rounded())); dismiss()
    }
}
