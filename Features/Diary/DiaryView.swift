import SwiftUI

struct DiaryView: View {
    @Environment(\.appEnvironment) private var env
    @StateObject private var vm = DiaryViewModel()
    @State private var editing: FoodEntry?
    @State private var pendingManualMeal: DiaryViewModel.Meal?
    @State private var showCustomFood = false
    @State private var scannedBarcode: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalorieSummaryCard(
                    goal: vm.goalKcal,
                    eaten: vm.totalKcal,
                    exercise: vm.exerciseKcal,
                    macros: vm.macroGoals
                )
                Divider()
                List {
                    ForEach(DiaryViewModel.Meal.allCases) { meal in
                        Section(meal.title) {
                            ForEach(vm.entriesFor(meal)) { e in
                                EntryRow(entry: e)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editing = e }
                            }
                            .onDelete { vm.delete(at: $0, in: meal) }

                            ForEach(vm.manualEntriesFor(meal)) { e in
                                ManualEntryRow(entry: e)
                            }
                            .onDelete { vm.deleteManualEntry(at: $0, in: meal) }

                            AddFoodMenu(
                                onScan:   { vm.activeMeal = meal; vm.showScanner = true },
                                onSearch: { vm.activeMeal = meal; vm.showSearch  = true },
                                onManual: { pendingManualMeal = meal }
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { vm.showHistory = true } label: { Image(systemName: "calendar") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { vm.showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $vm.showScanner) {
                ScannerSheet { code in
                    Task {
                        do {
                            let p = try await env.foodRepository.lookupBarcode(code)
                            if let m = vm.activeMeal { vm.append(p, to: m) }
                        } catch is FoodLookupError {
                            scannedBarcode = code
                            showCustomFood = true
                        } catch {
                            vm.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .sheet(isPresented: $vm.showSearch)   { SearchView { p in if let m = vm.activeMeal { vm.append(p, to: m) } } }
            .sheet(isPresented: $vm.showSettings) { SettingsView(profile: vm.profile) { vm.profile = $0 } }
            .sheet(item: $editing)                { e in EditSheet(entry: e) { g in vm.update(id: e.id, grams: g) } }
            .sheet(isPresented: $vm.showHistory)  { HistoryView() }
            .sheet(isPresented: $showCustomFood)  {
                CustomFoodView(barcode: scannedBarcode) { product in
                    if let m = vm.activeMeal { vm.append(product, to: m) }
                }
            }
            .sheet(item: $pendingManualMeal) { meal in
                ManualCalorieSheet(meal: meal) { kcal, note, selectedMeal in
                    vm.addManualEntry(calories: kcal, note: note, meal: selectedMeal)
                }
            }
            .alert("Error",
                   isPresented: Binding(get: { vm.errorMessage != nil },
                                        set: { _ in vm.errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: { Text(vm.errorMessage ?? "") }
            .onAppear {
                if vm.localStore == nil {
                    vm.restoreFromPersistence(store: env.localStore)
                }
            }
        }
    }
}

// MARK: - Header card

private struct CalorieSummaryCard: View {
    let goal: Int
    let eaten: Int
    let exercise: Int
    let macros: [DiaryViewModel.MacroGoal]

    private var remaining: Int { goal - eaten + exercise }
    private var progress: Double { goal > 0 ? min(1.0, Double(eaten) / Double(goal)) : 0 }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                calorieCol("Remaining", remaining, remaining < 0 ? .red : .primary, large: true)
                Divider().frame(height: 36)
                calorieCol("Goal", goal)
                Divider().frame(height: 36)
                calorieCol("Eaten", eaten)
                if exercise > 0 {
                    Divider().frame(height: 36)
                    calorieCol("Exercise", exercise, .green)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 5)
                    Capsule()
                        .fill(progress >= 1 ? Color.red : Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(progress), height: 5)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 5)

            HStack(spacing: 12) {
                ForEach(macros) { CompactMacroBar(goal: $0) }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private func calorieCol(_ label: String, _ value: Int, _ color: Color = .primary, large: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(large ? .title2.bold() : .subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CompactMacroBar: View {
    let goal: DiaryViewModel.MacroGoal

    private var color: Color {
        switch goal.kind {
        case .protein: .orange
        case .fat:     .purple
        case .carbs:   .teal
        }
    }

    private var label: String {
        switch goal.kind {
        case .protein: "Protein"
        case .fat:     "Fat"
        case .carbs:   "Carbs"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text(label).font(.caption2).foregroundStyle(color)
                Spacer()
                Text("\(Int(goal.eaten))/\(Int(goal.target))g")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15)).frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(goal.progress), height: 4)
                        .animation(.easeInOut, value: goal.progress)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Rows

private struct EntryRow: View {
    let entry: FoodEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.product.name)
                if let g = entry.product.nutriScore {
                    Text(g.uppercased())
                        .font(.caption2).bold()
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(nutriScoreColor(g).opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                Text("\(Int(entry.calories)) kcal")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text("\(Int(entry.grams)) g")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func nutriScoreColor(_ grade: String) -> Color {
        switch grade.lowercased() {
        case "a": .green
        case "b": .mint
        case "c": .yellow
        case "d": .orange
        default:  .red
        }
    }
}

private struct ManualEntryRow: View {
    let entry: ManualCalorieEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.note ?? "Manual entry")
                Text("Manual").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.calories) kcal")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Add food menu

private struct AddFoodMenu: View {
    var onScan: () -> Void
    var onSearch: () -> Void
    var onManual: () -> Void

    var body: some View {
        Menu {
            Button(action: onScan)   { Label("Scan Barcode", systemImage: "barcode.viewfinder") }
            Button(action: onSearch) { Label("Search Food",  systemImage: "magnifyingglass") }
            Button(action: onManual) { Label("Add Manually", systemImage: "pencil") }
        } label: {
            Label("Add Food", systemImage: "plus.circle").foregroundStyle(.tint)
        }
    }
}

// MARK: - Manual calorie sheet

private struct ManualCalorieSheet: View {
    @State private var kcalText = ""
    @State private var noteText = ""
    @State private var selectedMeal: DiaryViewModel.Meal
    var onSave: (Int, String?, DiaryViewModel.Meal) -> Void
    @Environment(\.dismiss) private var dismiss

    init(meal: DiaryViewModel.Meal, onSave: @escaping (Int, String?, DiaryViewModel.Meal) -> Void) {
        _selectedMeal = State(initialValue: meal)
        self.onSave = onSave
    }

    private var kcalValue: Int? { Int(kcalText.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(DiaryViewModel.Meal.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Calories") {
                    TextField("e.g. 250", text: $kcalText).keyboardType(.numberPad)
                }
                Section("Note (optional)") {
                    TextField("Snack, drink, etc.", text: $noteText)
                }
            }
            .navigationTitle("Manual Entry")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let kcal = kcalValue, kcal > 0 {
                            onSave(kcal, noteText.isEmpty ? nil : noteText, selectedMeal)
                            dismiss()
                        }
                    }
                    .disabled(kcalValue == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }
}
