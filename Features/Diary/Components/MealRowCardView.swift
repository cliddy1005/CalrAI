import SwiftUI

struct MealRowCardView: View {
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
    var onLog: () -> Void
    var onMenu: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 10) {
                Button(action: onMenu) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .foregroundColor(.secondary)
                }
                Button(action: onLog) {
                    Text("Log")
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
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
    MealRowCardView(
        icon: "sunrise.fill",
        title: "Breakfast",
        subtitle: "Oatmeal and 2 more",
        detail: "430 cal • C 52%  F 26%  P 22%",
        onLog: {},
        onMenu: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
