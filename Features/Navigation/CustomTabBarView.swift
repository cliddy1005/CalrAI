import SwiftUI

struct CustomTabBarView: View {
    @Binding var selected: AppShellView.Tab
    var onPlus: () -> Void

    var body: some View {
        HStack {
            tabButton(.today)
            tabButton(.plan)
            Spacer(minLength: 0)
            tabButton(.progress)
            tabButton(.more)
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .overlay(alignment: .top) {
            Button(action: onPlus) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                }
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .offset(y: -28)
        }
    }

    private func tabButton(_ tab: AppShellView.Tab) -> some View {
        Button {
            selected = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(tab.rawValue)
                    .font(.caption2)
            }
            .foregroundColor(selected == tab ? .black : .gray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CustomTabBarView(selected: .constant(.today), onPlus: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
