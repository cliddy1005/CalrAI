import Testing
import Foundation
import SwiftData
@testable import CalrAI

/// Tests for offline food caching: food fetched online should be available offline.
@MainActor
struct FoodCacheTests {
    private func makeLocalStore() -> LocalFoodStore {
        let schema = Schema([CachedFood.self, DiaryEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return LocalFoodStore(container: container)
    }

    @Test func cacheProductAndRetrieveByBarcode() {
        let store = makeLocalStore()
        let product = Product(
            barcode: "5000159484695",
            name: "Cadbury Dairy Milk",
            kcalPer100g: 534,
            proteinPer100g: 7.3,
            fatPer100g: 29.7,
            carbPer100g: 56.5,
            servingSizeGrams: 45,
            nutriScore: "e"
        )

        store.saveProduct(product)
        let cached = store.lookupBarcode("5000159484695")

        #expect(cached != nil)
        #expect(cached?.name == "Cadbury Dairy Milk")
        #expect(cached?.kcalPer100g == 534)
        #expect(cached?.proteinPer100g == 7.3)
        #expect(cached?.fatPer100g == 29.7)
        #expect(cached?.carbPer100g == 56.5)
        #expect(cached?.servingSizeGrams == 45)
    }

    @Test func cacheProductLiteAndRetrieveByBarcode() {
        let store = makeLocalStore()
        let lite = ProductLite(
            barcode: "8710398527189",
            name: "Heineken Lager",
            kcalPer100g: 42,
            nutriScore: nil,
            brands: "Heineken",
            stores: "Tesco",
            uniqueScans: 500
        )

        store.saveProductLite(lite)
        let cached = store.lookupBarcode("8710398527189")

        #expect(cached != nil)
        #expect(cached?.name == "Heineken Lager")
        #expect(cached?.brands == "Heineken")
        #expect(cached?.stores == "Tesco")
    }

    @Test func searchCachedFoodsByName() {
        let store = makeLocalStore()
        store.saveProduct(Product(barcode: "001", name: "Banana", kcalPer100g: 89,
                                   proteinPer100g: 1.1, fatPer100g: 0.3, carbPer100g: 22.8,
                                   servingSizeGrams: 118, nutriScore: "a"))
        store.saveProduct(Product(barcode: "002", name: "Apple", kcalPer100g: 52,
                                   proteinPer100g: 0.3, fatPer100g: 0.2, carbPer100g: 13.8,
                                   servingSizeGrams: 182, nutriScore: "a"))
        store.saveProduct(Product(barcode: "003", name: "Banana Chips", kcalPer100g: 519,
                                   proteinPer100g: 2.3, fatPer100g: 33.6, carbPer100g: 58.4,
                                   servingSizeGrams: 30, nutriScore: "d"))

        let results = store.searchFoods(query: "banana")
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.name.lowercased().contains("banana") })
    }

    @Test func upsertExistingBarcodeUpdatesRecord() {
        let store = makeLocalStore()
        store.saveProduct(Product(barcode: "111", name: "Old Name", kcalPer100g: 100,
                                   proteinPer100g: nil, fatPer100g: nil, carbPer100g: nil,
                                   servingSizeGrams: nil, nutriScore: nil))

        store.saveProduct(Product(barcode: "111", name: "Updated Name", kcalPer100g: 200,
                                   proteinPer100g: 10, fatPer100g: 5, carbPer100g: 25,
                                   servingSizeGrams: 50, nutriScore: "b"))

        let cached = store.lookupBarcode("111")
        #expect(cached?.name == "Updated Name")
        #expect(cached?.kcalPer100g == 200)
    }

    @Test func roundTripProductConversion() {
        let store = makeLocalStore()
        let original = Product(
            barcode: "999", name: "Test Food", kcalPer100g: 150,
            proteinPer100g: 8, fatPer100g: 5, carbPer100g: 20,
            servingSizeGrams: 100, nutriScore: "b"
        )

        store.saveProduct(original)
        let cached = store.lookupBarcode("999")!
        let converted = cached.toProduct()

        #expect(converted.barcode == original.barcode)
        #expect(converted.name == original.name)
        #expect(converted.kcalPer100g == original.kcalPer100g)
        #expect(converted.proteinPer100g == original.proteinPer100g)
        #expect(converted.fatPer100g == original.fatPer100g)
        #expect(converted.carbPer100g == original.carbPer100g)
    }
}
