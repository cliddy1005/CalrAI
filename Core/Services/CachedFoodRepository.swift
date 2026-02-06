import Foundation

/// Food repository that tries local cache first, falls back to remote,
/// and caches remote results for future offline use.
@MainActor
final class CachedFoodRepository: FoodRepository {
    private let remote: SearchService
    private let local: LocalFoodStore

    init(remote: SearchService, local: LocalFoodStore) {
        self.remote = remote
        self.local = local
    }

    func lookupBarcode(_ code: String) async throws -> Product {
        // Try remote first for freshest data
        do {
            let product = try await remote.product(code: code)
            local.saveProduct(product)
            return product
        } catch {
            // Fallback to local cache
            if let cached = local.lookupBarcode(code) {
                cached.lastAccessed = Date()
                local.saveContext()
                return cached.toProduct()
            }
            throw FoodLookupError.notFoundOffline(barcode: code)
        }
    }

    func searchFoods(query: String, country: String?, nearbyStoreSlugs: [String]) async throws -> [ProductLite] {
        let localResults = local.searchFoods(query: query).map { $0.toProductLite() }

        do {
            let remoteResults = try await remote.search(query: query, country: country, nearbyStoreSlugs: nearbyStoreSlugs)

            // Cache remote results in background
            for lite in remoteResults {
                local.saveProductLite(lite)
            }

            // Merge: remote results first, then local-only results not in remote set
            let remoteBarcodes = Set(remoteResults.map(\.barcode))
            let localOnly = localResults.filter { !remoteBarcodes.contains($0.barcode) }
            return remoteResults + localOnly
        } catch {
            // Offline: return local results only
            return localResults
        }
    }

    func save(food: Product) async throws {
        local.saveProduct(food)
    }

    func saveLite(food: ProductLite) async throws {
        local.saveProductLite(food)
    }
}

/// Errors specific to offline food lookup.
enum FoodLookupError: LocalizedError {
    case notFoundOffline(barcode: String)

    var errorDescription: String? {
        switch self {
        case .notFoundOffline(let barcode):
            return "Barcode \(barcode) not found offline. Connect to the internet or create a custom food entry."
        }
    }
}
