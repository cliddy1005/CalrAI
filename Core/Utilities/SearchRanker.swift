import Foundation

struct SearchRanker {
    static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
    static func popularityScore(_ n: Int?) -> Double {
        guard let n else { return 0 }
        return log(Double(n) + 1) / log(10.0)
    }
    static func brandOrStoreBoost(_ p: ProductLite, nearby: [Store], nearestOnly: Bool = true) -> Double {
        let names = (nearestOnly ? Array(nearby.prefix(1)) : nearby).map { norm($0.name) }
        let brand = norm(p.brands ?? "")
        let store = norm(p.stores ?? "")
        let hit = names.contains { brand.contains($0) || store.contains($0) }
        return hit ? 1.5 : 0.0
    }
    func rank(_ results: [ProductLite], query: String, nearbyStores: [Store]) -> [ProductLite] {
        let qn = Self.norm(query)
        return results.sorted { a, b in
            let aBoost = Self.brandOrStoreBoost(a, nearby: nearbyStores, nearestOnly: true)
            let bBoost = Self.brandOrStoreBoost(b, nearby: nearbyStores, nearestOnly: true)
            if aBoost != bBoost { return aBoost > bBoost }

            let aMatch = Self.norm(a.name).contains(qn) ? 1 : 0
            let bMatch = Self.norm(b.name).contains(qn) ? 1 : 0
            if aMatch != bMatch { return aMatch > bMatch }

            let aPop = Self.popularityScore(a.uniqueScans)
            let bPop = Self.popularityScore(b.uniqueScans)
            if aPop != bPop { return aPop > bPop }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    static let live = SearchRanker()
}
