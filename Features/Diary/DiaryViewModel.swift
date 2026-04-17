import Foundation
import SwiftUI

struct ManualCalorieEntry: Identifiable, Hashable {
    let id = UUID()
    let calories: Int
    let note: String?
    let meal: DiaryViewModel.Meal
}

@MainActor
final class DiaryViewModel: ObservableObject {
    enum Meal: String, CaseIterable, Identifiable, Codable { case breakfast, lunch, dinner, snacks; var id: Self { self }; var title: String { rawValue.capitalized } }

    @AppStorage("userProfile") private var stored = ""
    var profile: UserProfile {
        get { (try? JSONDecoder().decode(UserProfile.self, from: Data(stored.utf8))) ?? UserProfile() }
        set { stored = String(data: try! JSONEncoder().encode(newValue), encoding: .utf8)! }
    }

    @Published var entries: [FoodEntry] = []
    @Published var activeMeal: Meal?
    @Published var showScanner  = false
    @Published var showSearch   = false
    @Published var showSettings = false
    @Published var showHistory  = false
    @Published var errorMessage: String?
    @Published var exerciseKcal = 0
    @Published var manualEntries: [ManualCalorieEntry] = []

    /// Reference to local store for persistence. Set by DiaryView on appear.
    var localStore: LocalFoodStore?

    func append(_ p: Product, to meal: Meal) {
        entries.append(.init(product: p, grams: p.servingSizeGrams ?? 100, meal: meal))
        // Persist to SwiftData
        if let store = localStore {
            let entry = DiaryEntry(product: p, grams: p.servingSizeGrams ?? 100, meal: meal.rawValue)
            store.insertEntry(entry)
        }
    }
    func delete(at offsets: IndexSet, in meal: Meal) {
        let slice = entries.filter { $0.meal == meal }
        let idsToRemove = offsets.map { slice[$0].id }
        // Remove from persistence
        if let store = localStore {
            let today = store.fetchEntries(for: Date())
            for id in idsToRemove {
                if let entry = entries.first(where: { $0.id == id }) {
                    // Find matching persisted entry by food name + meal + approximate grams
                    if let persisted = today.first(where: {
                        $0.foodName == entry.product.name && $0.mealType == meal.rawValue && !$0.isManual
                    }) {
                        store.deleteEntry(persisted)
                    }
                }
            }
        }
        let global = offsets.compactMap { idx in entries.firstIndex(of: slice[idx]) }.sorted(by: >)
        for i in global { entries.remove(at: i) }
    }
    func update(id: UUID, grams: Double) {
        if let i = entries.firstIndex(where: { $0.id == id }) {
            entries[i].grams = grams
            // Update persistence
            if let store = localStore {
                let today = store.fetchEntries(for: Date())
                if let persisted = today.first(where: {
                    $0.foodName == entries[i].product.name && $0.mealType == entries[i].meal.rawValue && !$0.isManual
                }) {
                    persisted.grams = grams
                    persisted.recalculate()
                    store.saveContext()
                }
            }
        }
    }
    func entriesFor(_ meal: Meal) -> [FoodEntry] { entries.filter { $0.meal == meal } }

    var totalKcal: Int {
        let mealKcal = entries.reduce(0) { $0 + Int($1.calories) }
        let manualKcal = manualEntries.reduce(0) { $0 + $1.calories }
        return mealKcal + manualKcal
    }
    var totals: (p: Double, c: Double, f: Double) {
        entries.reduce(into: (0,0,0)) { acc, e in acc.0 += e.protein; acc.1 += e.carbs; acc.2 += e.fat }
    }
    var goalKcal: Int { Int(profile.macroTargets().kcal) }
    var remainingKcal: Int { goalKcal - totalKcal + exerciseKcal }

    struct MacroGoal: Identifiable {
        enum Kind { case carbs, fat, protein }
        var id: Kind { kind }
        let kind: Kind; let eaten, target: Double
        var remaining: Double { max(0, target - eaten) }
        var progress: Double { target == 0 ? 0 : min(1, eaten / target) }
    }
    var macroGoals: [MacroGoal] {
        let t = profile.macroTargets()
        return [
            .init(kind: .carbs,   eaten: totals.c, target: t.c),
            .init(kind: .fat,     eaten: totals.f, target: t.f),
            .init(kind: .protein, eaten: totals.p, target: t.p)
        ]
    }

    func manualEntriesFor(_ meal: Meal) -> [ManualCalorieEntry] {
        manualEntries.filter { $0.meal == meal }
    }

    func addManualEntry(calories: Int, note: String? = nil, meal: Meal) {
        manualEntries.append(ManualCalorieEntry(calories: calories, note: note, meal: meal))
        if let store = localStore {
            let entry = DiaryEntry.manual(calories: calories, note: note, meal: meal.rawValue)
            store.insertEntry(entry)
        }
    }

    func deleteManualEntry(at offsets: IndexSet, in meal: Meal) {
        let slice = manualEntries.filter { $0.meal == meal }
        let idsToRemove = offsets.map { slice[$0].id }
        if let store = localStore {
            let today = store.fetchEntries(for: Date())
            for id in idsToRemove {
                if let manual = manualEntries.first(where: { $0.id == id }),
                   let persisted = today.first(where: {
                       $0.isManual && $0.caloriesSnapshot == manual.calories && $0.mealType == meal.rawValue
                   }) {
                    store.deleteEntry(persisted)
                }
            }
        }
        manualEntries.removeAll { idsToRemove.contains($0.id) }
    }

    /// Restore today's entries from persistence on app launch.
    func restoreFromPersistence(store: LocalFoodStore) {
        self.localStore = store
        let todayEntries = store.fetchEntries(for: Date())
        for entry in todayEntries {
            if entry.isManual {
                manualEntries.append(ManualCalorieEntry(
                    calories: entry.caloriesSnapshot,
                    note: entry.note,
                    meal: Meal(rawValue: entry.mealType) ?? .snacks
                ))
            } else {
                let product = entry.toProduct()
                let meal = Meal(rawValue: entry.mealType) ?? .snacks
                entries.append(FoodEntry(product: product, grams: entry.grams, meal: meal))
            }
        }
    }
}
