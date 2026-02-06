import Foundation
import SwiftData

/// Persistent diary entry stored via SwiftData.
/// Each entry represents a single food item logged to a meal on a given date.
@Model
final class DiaryEntry {
    var id: UUID
    var date: Date
    var mealType: String  // breakfast, lunch, dinner, snacks
    var foodBarcode: String?
    var foodName: String
    var foodBrand: String?
    var grams: Double
    var caloriesSnapshot: Int
    var proteinSnapshot: Double
    var fatSnapshot: Double
    var carbsSnapshot: Double
    var note: String?
    var isManual: Bool

    // Denormalized per-100g values so we can recalculate if grams change
    var kcalPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var carbPer100g: Double
    var servingSizeGrams: Double?
    var nutriScore: String?

    init(date: Date = Date(), mealType: String, foodBarcode: String? = nil,
         foodName: String, foodBrand: String? = nil, grams: Double,
         kcalPer100g: Double = 0, proteinPer100g: Double = 0,
         fatPer100g: Double = 0, carbPer100g: Double = 0,
         servingSizeGrams: Double? = nil, nutriScore: String? = nil,
         note: String? = nil, isManual: Bool = false) {
        self.id = UUID()
        self.date = date
        self.mealType = mealType
        self.foodBarcode = foodBarcode
        self.foodName = foodName
        self.foodBrand = foodBrand
        self.grams = grams
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbPer100g = carbPer100g
        self.servingSizeGrams = servingSizeGrams
        self.nutriScore = nutriScore
        self.note = note
        self.isManual = isManual

        // Snapshot macros
        if isManual {
            self.caloriesSnapshot = Int(kcalPer100g) // For manual entries, stored directly
            self.proteinSnapshot = 0
            self.fatSnapshot = 0
            self.carbsSnapshot = 0
        } else {
            self.caloriesSnapshot = Int((kcalPer100g * grams / 100).rounded())
            self.proteinSnapshot = (proteinPer100g * grams / 100).rounded()
            self.fatSnapshot = (fatPer100g * grams / 100).rounded()
            self.carbsSnapshot = (carbPer100g * grams / 100).rounded()
        }
    }

    /// Recalculate snapshots after editing grams.
    func recalculate() {
        guard !isManual else { return }
        caloriesSnapshot = Int((kcalPer100g * grams / 100).rounded())
        proteinSnapshot = (proteinPer100g * grams / 100).rounded()
        fatSnapshot = (fatPer100g * grams / 100).rounded()
        carbsSnapshot = (carbPer100g * grams / 100).rounded()
    }

    /// Build a Product from this entry's stored nutritional data.
    func toProduct() -> Product {
        Product(barcode: foodBarcode ?? "", name: foodName,
                kcalPer100g: kcalPer100g,
                proteinPer100g: proteinPer100g,
                fatPer100g: fatPer100g,
                carbPer100g: carbPer100g,
                servingSizeGrams: servingSizeGrams,
                nutriScore: nutriScore)
    }

    /// Build a FoodEntry (in-memory) from this persistent entry.
    func toFoodEntry(meal: DiaryViewModel.Meal) -> FoodEntry {
        FoodEntry(product: toProduct(), grams: grams, meal: meal)
    }

    /// Create from a Product + meal context.
    convenience init(product: Product, grams: Double, meal: String, date: Date = Date()) {
        self.init(
            date: date, mealType: meal,
            foodBarcode: product.barcode, foodName: product.name,
            grams: grams,
            kcalPer100g: product.kcalPer100g,
            proteinPer100g: product.proteinPer100g ?? 0,
            fatPer100g: product.fatPer100g ?? 0,
            carbPer100g: product.carbPer100g ?? 0,
            servingSizeGrams: product.servingSizeGrams,
            nutriScore: product.nutriScore
        )
    }

    /// Create a manual calorie entry.
    static func manual(calories: Int, note: String?, meal: String, date: Date = Date()) -> DiaryEntry {
        DiaryEntry(
            date: date, mealType: meal,
            foodName: note ?? "Manual entry",
            grams: 0, kcalPer100g: Double(calories),
            note: note, isManual: true
        )
    }
}
