import Foundation

struct FoodEntry: Identifiable, Hashable {
    let id = UUID()
    let product: Product
    var grams: Double
    let meal: DiaryViewModel.Meal

    private func of(_ v: Double?) -> Double { (v ?? 0) * grams / 100 }
    var calories: Double { of(product.kcalPer100g) }
    var protein : Double { of(product.proteinPer100g) }
    var fat     : Double { of(product.fatPer100g) }
    var carbs   : Double { of(product.carbPer100g) }
}
