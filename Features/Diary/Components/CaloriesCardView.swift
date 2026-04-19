import SwiftUI

struct CaloriesCardView: View {
    let current: Int
    let target: Int

    private var left: Int { max(0, target - current) }
    private var progress: Double { target == 0 ? 0 : min(1, Double(current) / Double(target)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calories")
                .font(.headline)
            HStack(alignment: .firstTextBaseline) {
                Text("\(current) cal")
                    .font(.system(size: 28, weight: .bold))
                Text("/ \(target)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(left) left")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            ProgressBarView(value: progress, color: .blue)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    CaloriesCardView(current: 976, target: 2074)
        .padding()
        .background(Color(.systemGroupedBackground))
}
