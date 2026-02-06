import Foundation

/// Protocol defining food lookup operations, supporting both online and offline usage.
protocol FoodRepository {
    /// Search foods by text query. Returns merged local + remote results.
    func searchFoods(query: String, country: String?, nearbyStoreSlugs: [String]) async throws -> [ProductLite]

    /// Lookup a single product by barcode. Returns cached version if offline.
    func lookupBarcode(_ code: String) async throws -> Product

    /// Save a food to the local cache (e.g., a custom food entry).
    func save(food: Product) async throws

    /// Save a ProductLite to local cache (from search results).
    func saveLite(food: ProductLite) async throws
}
