import SwiftUI

struct MacrosCardView: View {
    struct Macro: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
        let target: Int
        let color: Color
    }

    let macros: [Macro]
    var onSwap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Macros")
                    .font(.headline)
                Spacer()
                Button(action: onSwap) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            HStack(spacing: 16) {
                ForEach(macros) { macro in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(macro.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(macro.value) g / \(macro.target)")
                            .font(.subheadline.weight(.semibold))
                        ProgressBarView(
                            value: macro.target == 0 ? 0 : min(1, Double(macro.value) / Double(macro.target)),
                            color: macro.color
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    MacrosCardView(
        macros: [
            .init(label: "Carbs", value: 125, target: 260, color: .blue),
            .init(label: "Fat", value: 40, target: 70, color: .orange),
            .init(label: "Protein", value: 90, target: 140, color: .green)
        ],
        onSwap: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
