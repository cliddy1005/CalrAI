import Foundation
import SwiftUI

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
    @Published var errorMessage: String?
    @Published var exerciseKcal = 0

    func append(_ p: Product, to meal: Meal) {
        entries.append(.init(product: p, grams: p.servingSizeGrams ?? 100, meal: meal))
    }
    func delete(at offsets: IndexSet, in meal: Meal) {
        let slice = entries.filter { $0.meal == meal }
        let global = offsets.compactMap { idx in entries.firstIndex(of: slice[idx]) }.sorted(by: >)
        for i in global { entries.remove(at: i) }
    }
    func update(id: UUID, grams: Double) {
        if let i = entries.firstIndex(where: { $0.id == id }) { entries[i].grams = grams }
    }
    func entriesFor(_ meal: Meal) -> [FoodEntry] { entries.filter { $0.meal == meal } }

    var totalKcal: Int { entries.reduce(0) { $0 + Int($1.calories) } }
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
}
