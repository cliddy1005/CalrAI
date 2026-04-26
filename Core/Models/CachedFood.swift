import Foundation
import SwiftData

/// Persistent food model stored locally for offline lookup.
/// Mirrors the essential fields from Product/ProductLite so that
/// once a food has been seen online it can be retrieved offline.
@Model
final class CachedFood {
    @Attribute(.unique) var barcode: String
    var name: String
    var brands: String?
    var stores: String?
    var kcalPer100g: Double
    var proteinPer100g: Double?
    var fatPer100g: Double?
    var carbPer100g: Double?
    var servingSizeGrams: Double?
    var nutriScore: String?
    var uniqueScans: Int?
    var lastAccessed: Date
    var isCustom: Bool

    init(barcode: String, name: String, brands: String? = nil, stores: String? = nil,
         kcalPer100g: Double, proteinPer100g: Double? = nil, fatPer100g: Double? = nil,
         carbPer100g: Double? = nil, servingSizeGrams: Double? = nil, nutriScore: String? = nil,
         uniqueScans: Int? = nil, isCustom: Bool = false) {
        self.barcode = barcode
        self.name = name
        self.brands = brands
        self.stores = stores
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbPer100g = carbPer100g
        self.servingSizeGrams = servingSizeGrams
        self.nutriScore = nutriScore
        self.uniqueScans = uniqueScans
        self.lastAccessed = Date()
        self.isCustom = isCustom
    }

    /// Convert from an API Product to a cacheable model.
    convenience init(from product: Product) {
        self.init(
            barcode: product.barcode,
            name: product.name,
            kcalPer100g: product.kcalPer100g,
            proteinPer100g: product.proteinPer100g,
            fatPer100g: product.fatPer100g,
            carbPer100g: product.carbPer100g,
            servingSizeGrams: product.servingSizeGrams,
            nutriScore: product.nutriScore
        )
    }

    /// Convert from a ProductLite (search result) to a cacheable model.
    convenience init(from lite: ProductLite) {
        self.init(
            barcode: lite.barcode,
            name: lite.name,
            brands: lite.brands,
            stores: lite.stores,
            kcalPer100g: lite.kcalPer100g ?? 0,
            nutriScore: lite.nutriScore,
            uniqueScans: lite.uniqueScans
        )
    }

    /// Convert back to a Product for use in the existing app layer.
    func toProduct() -> Product {
        Product(
            barcode: barcode,
            name: name,
            kcalPer100g: kcalPer100g,
            proteinPer100g: proteinPer100g,
            fatPer100g: fatPer100g,
            carbPer100g: carbPer100g,
            servingSizeGrams: servingSizeGrams,
            nutriScore: nutriScore
        )
    }

    /// Convert back to ProductLite for search results.
    func toProductLite() -> ProductLite {
        ProductLite(
            barcode: barcode, name: name,
            kcalPer100g: kcalPer100g,
            nutriScore: nutriScore,
            brands: brands, stores: stores,
            uniqueScans: uniqueScans
        )
    }
}
