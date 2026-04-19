import Foundation

/// Domain model used across local + remote food lookup.
struct Food: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let barcode: String
    let quantity: String?
    let countriesTags: [String]?
    let kcalPer100g: Double
    let proteinPer100g: Double?
    let carbPer100g: Double?
    let fatPer100g: Double?
    let servingSizeGrams: Double?
    let imageUrl: String?
    let lastFetchedAt: Date?
    let popularity: Int?
    let source: String
}
