import Testing
import Foundation
import SwiftData
@testable import CalrAI

/// Tests for diary entry persistence: create entry, fetch by date.
@MainActor
struct DiaryPersistenceTests {
    private func makeLocalStore() -> LocalFoodStore {
        let schema = Schema([CachedFood.self, DiaryEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return LocalFoodStore(container: container)
    }

    @Test func insertAndFetchEntryByDate() {
        let store = makeLocalStore()
        let today = Date()
        let entry = DiaryEntry(
            date: today, mealType: "breakfast",
            foodBarcode: "123456", foodName: "Oats",
            grams: 50, kcalPer100g: 379,
            proteinPer100g: 13.2, fatPer100g: 6.5, carbPer100g: 67.7
        )

        store.insertEntry(entry)
        let fetched = store.fetchEntries(for: today)

        #expect(fetched.count == 1)
        #expect(fetched.first?.foodName == "Oats")
        #expect(fetched.first?.mealType == "breakfast")
        #expect(fetched.first?.caloriesSnapshot == 190) // 379 * 50 / 100 = 189.5 -> 190
        #expect(fetched.first?.grams == 50)
    }

    @Test func multipleEntriesAcrossDates() {
        let store = makeLocalStore()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        store.insertEntry(DiaryEntry(
            date: today, mealType: "lunch",
            foodName: "Chicken Breast", grams: 150,
            kcalPer100g: 165, proteinPer100g: 31, fatPer100g: 3.6, carbPer100g: 0
        ))
        store.insertEntry(DiaryEntry(
            date: yesterday, mealType: "dinner",
            foodName: "Salmon", grams: 200,
            kcalPer100g: 208, proteinPer100g: 20, fatPer100g: 13, carbPer100g: 0
        ))

        let todayEntries = store.fetchEntries(for: today)
        let yesterdayEntries = store.fetchEntries(for: yesterday)

        #expect(todayEntries.count == 1)
        #expect(todayEntries.first?.foodName == "Chicken Breast")
        #expect(yesterdayEntries.count == 1)
        #expect(yesterdayEntries.first?.foodName == "Salmon")
    }

    @Test func deleteEntry() {
        let store = makeLocalStore()
        let entry = DiaryEntry(
            date: Date(), mealType: "snacks",
            foodName: "Cookie", grams: 30,
            kcalPer100g: 502, proteinPer100g: 5, fatPer100g: 25, carbPer100g: 65
        )

        store.insertEntry(entry)
        #expect(store.fetchEntries(for: Date()).count == 1)

        store.deleteEntry(entry)
        #expect(store.fetchEntries(for: Date()).count == 0)
    }

    @Test func manualCalorieEntry() {
        let store = makeLocalStore()
        let manual = DiaryEntry.manual(calories: 350, note: "Coffee with milk", meal: "breakfast")

        store.insertEntry(manual)
        let fetched = store.fetchEntries(for: Date())

        #expect(fetched.count == 1)
        #expect(fetched.first?.isManual == true)
        #expect(fetched.first?.caloriesSnapshot == 350)
        #expect(fetched.first?.note == "Coffee with milk")
    }

    @Test func editEntryGramsRecalculates() {
        let store = makeLocalStore()
        let entry = DiaryEntry(
            date: Date(), mealType: "lunch",
            foodName: "Rice", grams: 100,
            kcalPer100g: 130, proteinPer100g: 2.7, fatPer100g: 0.3, carbPer100g: 28
        )

        store.insertEntry(entry)
        #expect(entry.caloriesSnapshot == 130)

        entry.grams = 200
        entry.recalculate()
        store.saveContext()

        let fetched = store.fetchEntries(for: Date())
        #expect(fetched.first?.caloriesSnapshot == 260) // 130 * 200 / 100
        #expect(fetched.first?.grams == 200)
    }

    @Test func fetchEntriesInDateRange() {
        let store = makeLocalStore()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            store.insertEntry(DiaryEntry(
                date: date, mealType: "lunch",
                foodName: "Day \(dayOffset)", grams: 100,
                kcalPer100g: Double(100 + dayOffset * 10)
            ))
        }

        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let weekEnd = calendar.date(byAdding: .day, value: 1, to: today)!
        let weekEntries = store.fetchEntries(from: weekStart, to: weekEnd)

        #expect(weekEntries.count == 7)
    }
}
