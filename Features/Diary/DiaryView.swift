import SwiftUI

struct DiaryView: View {
    @Environment(\.appEnvironment) private var env
    @StateObject private var vm = DiaryViewModel()
    @State private var editing: FoodEntry?

    private func metric(_ t: String, _ v: Int, _ col: Color = .primary) -> some View {
        VStack(spacing: 1) {
            Text(t).font(.caption2).foregroundColor(.secondary)
            Text(v.formatted()).font(.footnote.weight(.semibold)).foregroundColor(col)
        }
    }
    private func actionRow(icon: String, text: String, meal: DiaryViewModel.Meal, trigger: @escaping () -> Void) -> some View {
        Button { vm.activeMeal = meal; trigger() } label: { HStack { Image(systemName: icon); Text(text) } }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    metric("Goal", vm.goalKcal); Text("–")
                    metric("Food", vm.totalKcal); Text("+")
                    metric("Exercise", vm.exerciseKcal); Text("=")
                    metric("Remaining", vm.remainingKcal, vm.remainingKcal >= 0 ? .green : .red)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 32) {
                        ForEach(vm.macroGoals) { g in
                            MacroRing(g: g)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 20).fill(.background).shadow(radius: 4))
                .padding(.horizontal)

                List {
                    ForEach(DiaryViewModel.Meal.allCases) { meal in
                        Section(header: Text(meal.title)) {
                            ForEach(vm.entriesFor(meal)) { e in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(e.product.name)
                                        if let g = e.product.nutriScore {
                                            Text(g.uppercased()).font(.caption2)
                                                .padding(4).background(Color.gray.opacity(0.2))
                                                .clipShape(Circle())
                                        }
                                    }
                                    Text("\(Int(e.grams)) g • \(Int(e.calories)) kcal")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { editing = e }
                            }
                            .onDelete { withAnimation { vm.delete(at: $0, in: meal) } }
                            actionRow(icon: "barcode.viewfinder", text: "Scan Barcode", meal: meal) { vm.showScanner = true }
                            actionRow(icon: "magnifyingglass", text: "Search Food", meal: meal) { vm.showSearch = true }
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
            .sheet(isPresented: $vm.showScanner)  { ScannerSheet { code in
                Task {
                    do { let p = try await env.search.product(code: code); if let m = vm.activeMeal { vm.append(p, to: m) } }
                    catch { vm.errorMessage = error.localizedDescription }
                }
            }}
            .sheet(isPresented: $vm.showSearch)   { SearchView { p in if let m = vm.activeMeal { vm.append(p, to: m) } } }
            .sheet(isPresented: $vm.showSettings) { SettingsView(profile: vm.profile) { vm.profile = $0 } }
            .sheet(item: $editing) { e in EditSheet(entry: e) { g in vm.update(id: e.id, grams: g) } }
            .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: { Text(vm.errorMessage ?? "") }
        }
    }
}

// Small ring reused
struct MacroRing: View {
    let g: DiaryViewModel.MacroGoal
    private var col: Color { switch g.id { case .carbs: .teal; case .fat: .purple; case .protein: .orange } }
    private var title: String { switch g.id { case .carbs: "Carbs"; case .fat: "Fat"; case .protein: "Protein" } }
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.headline).foregroundStyle(col)
            ZStack {
                Circle().stroke(.gray.opacity(0.15), lineWidth: 14)
                Circle().trim(from: 0, to: g.progress)
                    .stroke(col, style: .init(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: g.progress)
                VStack(spacing: 0) {
                    Text(Int(g.eaten).formatted()).font(.title3).bold()
                    Text("/\(Int(g.target))g").font(.caption).foregroundColor(.secondary)
                }
            }.frame(width: 110, height: 110)
            Text("\(Int(g.remaining))g left").font(.caption).foregroundColor(.secondary)
        }
    }
}
