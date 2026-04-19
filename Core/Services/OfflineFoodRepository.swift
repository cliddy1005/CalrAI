import Foundation

@MainActor
final class OfflineFoodRepository: FoodRepository {
    private let db: LocalFoodDatabase
    private let localStore: LocalFoodStore
    private let remote: OpenFoodFactsClient?

    init(db: LocalFoodDatabase, localStore: LocalFoodStore, allowRemote: Bool) {
        self.db = db
        self.localStore = localStore
        self.remote = allowRemote ? OpenFoodFactsClient() : nil
    }

    func searchFoods(query: String, limit: Int) async -> [Food] {
        AppLog.log(AppLog.repoSearch, "search start query=\(query) limit=\(limit)")
        let local = localStore.searchFoods(query: query, limit: limit).map { $0.toFood() }
        var results = merge(local, db.searchFoods(query: query, limit: limit))

        if results.count < limit, let remote {
            AppLog.log(AppLog.repoSearch, "search remote fallback count=\(results.count)")
            if let remoteResults = try? await remote.searchFoods(query: query, limit: limit - results.count) {
                localStore.upsert(foods: remoteResults)
                results = merge(results, remoteResults)
            }
        }
        AppLog.log(AppLog.repoSearch, "search end results=\(results.count)")
        return Array(results.prefix(limit))
    }

    func lookupBarcode(_ code: String) async -> Food? {
        AppLog.log(AppLog.repoBarcode, "barcode lookup start code=\(code)")
        if let cached = localStore.lookupBarcode(code)?.toFood() {
            AppLog.log(AppLog.repoBarcode, "barcode hit localStore")
            return cached
        }
        if let fromDb = db.lookupBarcode(code) {
            AppLog.log(AppLog.repoBarcode, "barcode hit offline DB")
            return fromDb
        }
        if let remote {
            AppLog.log(AppLog.repoBarcode, "barcode remote fallback")
            if let food = try? await remote.lookupBarcode(code) {
                localStore.upsert(foods: [food])
                return food
            }
        }
        AppLog.log(AppLog.repoBarcode, "barcode miss")
        return nil
    }

    func upsertFoods(_ foods: [Food]) async {
        localStore.upsert(foods: foods)
    }

    private func merge(_ a: [Food], _ b: [Food]) -> [Food] {
        var seen = Set<String>()
        var merged: [Food] = []
        for item in a + b {
            if seen.insert(item.barcode).inserted {
                merged.append(item)
            }
        }
        return merged
    }
}
