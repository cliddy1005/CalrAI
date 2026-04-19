import SwiftUI

struct AppShellView: View {
    enum Tab: String, CaseIterable {
        case today = "Today"
        case plan = "Plan"
        case progress = "Progress"
        case more = "More"

        var icon: String {
            switch self {
            case .today: return "house.fill"
            case .plan: return "checklist"
            case .progress: return "chart.bar.fill"
            case .more: return "ellipsis"
            }
        }
    }

    @StateObject private var diaryVM = DiaryViewModel()
    @State private var selectedTab: Tab = .today
    @State private var showLogMenu = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .today:
                    DiaryView(vm: diaryVM)
                case .plan:
                    PlaceholderView(title: "Plan")
                case .progress:
                    PlaceholderView(title: "Progress")
                case .more:
                    PlaceholderView(title: "More")
                }
            }

            CustomTabBarView(selected: $selectedTab) {
                showLogMenu = true
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .confirmationDialog("Log Food", isPresented: $showLogMenu, titleVisibility: .visible) {
            Button("Search Food") {
                diaryVM.activeMeal = .lunch
                diaryVM.showSearch = true
            }
            Button("Scan Barcode") {
                diaryVM.activeMeal = .lunch
                diaryVM.showScanner = true
            }
            Button("Custom Food") {
                diaryVM.activeMeal = .lunch
            }
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AppShellView()
}
