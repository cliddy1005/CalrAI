import Foundation
import SwiftUI

struct TodayDashboardViewModel {
    struct MealSummary: Identifiable {
        let id = UUID()
        let meal: DiaryViewModel.Meal
        let subtitle: String
        let detail: String
    }

    let date: Date
    let streakCount: Int
    let caloriesCurrent: Int
    let caloriesTarget: Int
    let macros: [(label: String, value: Int, target: Int)]
    let weekDays: [Date]
    let meals: [MealSummary]

    @MainActor
    static func build(from diary: DiaryViewModel) -> TodayDashboardViewModel {
        let date = diary.selectedDate
        let streak = diary.streakCount
        let kcalTarget = diary.goalKcal
        let kcalCurrent = diary.totalKcal

        let targets = diary.profile.macroTargets()
        let macros = [
            ("Carbs", Int(diary.totals.c.rounded()), Int(targets.c)),
            ("Fat", Int(diary.totals.f.rounded()), Int(targets.f)),
            ("Protein", Int(diary.totals.p.rounded()), Int(targets.p))
        ]

        let weekDays = diary.weekDays

        let meals = DiaryViewModel.Meal.allCases.map { meal in
            let entries = diary.entriesFor(meal)
            let subtitle: String
            let detail: String
            if entries.isEmpty {
                subtitle = "No entries yet"
                detail = "0 cal • C 0%  F 0%  P 0%"
            } else {
                let first = entries[0].product.name
                let more = max(0, entries.count - 1)
                subtitle = more > 0 ? "\(first) and \(more) more" : first
                let mealKcal = entries.reduce(0) { $0 + Int($1.calories) }
                let macros = mealMacroPercentages(entries)
                detail = "\(mealKcal) cal • C \(macros.c)%  F \(macros.f)%  P \(macros.p)%"
            }
            return MealSummary(meal: meal, subtitle: subtitle, detail: detail)
        }

        return TodayDashboardViewModel(
            date: date,
            streakCount: streak,
            caloriesCurrent: kcalCurrent,
            caloriesTarget: kcalTarget,
            macros: macros,
            weekDays: weekDays,
            meals: meals
        )
    }

    private static func mealMacroPercentages(_ entries: [FoodEntry]) -> (c: Int, f: Int, p: Int) {
        let carbs = entries.reduce(0.0) { $0 + $1.carbs }
        let fat = entries.reduce(0.0) { $0 + $1.fat }
        let protein = entries.reduce(0.0) { $0 + $1.protein }
        let total = max(1.0, carbs + fat + protein)
        let c = Int((carbs / total * 100).rounded())
        let f = Int((fat / total * 100).rounded())
        let p = max(0, 100 - c - f)
        return (c, f, p)
    }
}

struct TodayDashboardViewModel_Previews: PreviewProvider {
    static var previews: some View {
        DiaryView(vm: DiaryViewModel())
    }
}
