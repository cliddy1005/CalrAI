import Foundation
import SwiftData

/// Local persistence layer for cached food data using SwiftData.
@MainActor
final class LocalFoodStore {
    private let container: ModelContainer

    var modelContext: ModelContext {
        container.mainContext
    }

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Food Cache

    func lookupBarcode(_ code: String) -> CachedFood? {
        let descriptor = FetchDescriptor<CachedFood>(
            predicate: #Predicate<CachedFood> { $0.barcode == code }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func searchFoods(query: String) -> [CachedFood] {
        let lowered = query.lowercased()
        let descriptor = FetchDescriptor<CachedFood>(
            predicate: #Predicate<CachedFood> {
                $0.name.localizedStandardContains(lowered) ||
                ($0.brands ?? "").localizedStandardContains(lowered)
            },
            sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func save(food: CachedFood) {
        // Upsert: if barcode exists, update; otherwise insert
        if let existing = lookupBarcode(food.barcode) {
            existing.name = food.name
            existing.brands = food.brands
            existing.stores = food.stores
            existing.kcalPer100g = food.kcalPer100g
            existing.proteinPer100g = food.proteinPer100g
            existing.fatPer100g = food.fatPer100g
            existing.carbPer100g = food.carbPer100g
            existing.servingSizeGrams = food.servingSizeGrams
            existing.nutriScore = food.nutriScore
            existing.uniqueScans = food.uniqueScans
            existing.lastAccessed = Date()
        } else {
            modelContext.insert(food)
        }
        try? modelContext.save()
    }

    func saveProduct(_ product: Product) {
        save(food: CachedFood(from: product))
    }

    func saveProductLite(_ lite: ProductLite) {
        save(food: CachedFood(from: lite))
    }

    // MARK: - Diary Entries

    func fetchEntries(for date: Date) -> [DiaryEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchEntries(from startDate: Date, to endDate: Date) -> [DiaryEntry] {
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { $0.date >= startDate && $0.date < endDate },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func insertEntry(_ entry: DiaryEntry) {
        modelContext.insert(entry)
        try? modelContext.save()
    }

    func deleteEntry(_ entry: DiaryEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    func saveContext() {
        try? modelContext.save()
    }

    // MARK: - Utility

    func deleteAllData() {
        try? modelContext.delete(model: CachedFood.self)
        try? modelContext.delete(model: DiaryEntry.self)
        try? modelContext.save()
    }
}
