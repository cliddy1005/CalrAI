import SwiftUI

struct DiaryView: View {
    @Environment(\.appEnvironment) private var env
    @StateObject private var vm = DiaryViewModel()
    @State private var editing: FoodEntry?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalorieBanner(goal: vm.goalKcal, food: vm.totalKcal, exercise: vm.exerciseKcal)
                MacroStrip(goals: vm.macroGoals)

                List {
                    ForEach(DiaryViewModel.Meal.allCases) { meal in
                        Section(header: Text(meal.title)) {
                            ForEach(vm.entriesFor(meal)) { e in
                                EntryRow(entry: e)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editing = e }
                            }
                            .onDelete { offsets in
                                withAnimation { vm.delete(at: offsets, in: meal) }
                            }

                            ActionRow(icon: "barcode.viewfinder", label: "Scan Barcode") {
                                vm.activeMeal = meal; vm.showScanner = true
                            }
                            ActionRow(icon: "magnifyingglass", label: "Search Food") {
                                vm.activeMeal = meal; vm.showSearch = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Today \(vm.totalKcal) kcal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { vm.showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $vm.showScanner)  {
                ScannerSheet { code in
                    Task {
                        do { let p = try await env.search.product(code: code)
                            if let m = vm.activeMeal { vm.append(p, to: m) }
                        } catch { vm.errorMessage = error.localizedDescription }
                    }
                }
            }
            .sheet(isPresented: $vm.showSearch)   { SearchView { p in if let m = vm.activeMeal { vm.append(p, to: m) } } }
            .sheet(isPresented: $vm.showSettings) { SettingsView(profile: vm.profile) { vm.profile = $0 } }
            .sheet(item: $editing) { e in EditSheet(entry: e) { g in vm.update(id: e.id, grams: g) } }
            .alert("Error",
                   isPresented: Binding(get: { vm.errorMessage != nil },
                                        set: { _ in vm.errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: { Text(vm.errorMessage ?? "") }
        }
    }
}

// MARK: - Small subviews

private struct CalorieBanner: View {
    let goal: Int
    let food: Int
    let exercise: Int
    private var remaining: Int { goal - food + exercise }

    private func metric(_ t: String, _ v: Int, _ col: Color = .primary) -> some View {
        VStack(spacing: 1) {
            Text(t).font(.caption2).foregroundColor(.secondary)
            Text(v.formatted()).font(.footnote.weight(.semibold)).foregroundColor(col)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            metric("Goal", goal); Text("–")
            metric("Food", food); Text("+")
            metric("Exercise", exercise); Text("=")
            metric("Remaining", remaining, remaining >= 0 ? .green : .red)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

private struct MacroStrip: View {
    let goals: [DiaryViewModel.MacroGoal]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 32) {
                ForEach(goals) { g in MacroRing(g: g) }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(.background).shadow(radius: 4))
        .padding(.horizontal)
    }
}

private struct EntryRow: View {
    let entry: FoodEntry
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(entry.product.name)
                if let g = entry.product.nutriScore {
                    Text(g.uppercased())
                        .font(.caption2)
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            Text("\(Int(entry.grams)) g • \(Int(entry.calories)) kcal")
                .font(.caption).foregroundColor(.secondary)
        }
    }
}

private struct ActionRow: View {
    let icon: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Image(systemName: icon); Text(label) }
        }
    }
}
