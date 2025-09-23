import Foundation
import CoreLocation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [ProductLite] = []
    @Published var loading = false
    @Published var stores: [Store] = []
    @Published var countryHint: String?

    private let search: SearchService
    private let location: LocationProvider
    private let ranker: SearchRanker

    init(search: SearchService, location: LocationProvider, ranker: SearchRanker = .live) {
        self.search = search
        self.location = location
        self.ranker = ranker
    }

    func askLocation() {
        if location.authorization == .notDetermined {
            location.requestWhenInUse()
        }
    }

    func refreshGeoContext() async {
        guard let here = location.location else { return }
        let nearby = await NearbyStoresService.find(around: here)
        self.stores = nearby
        if let country = await reverseGeocodeCountry(from: here) {
            self.countryHint = country
        }
    }

    func performSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { results = []; return }
        loading = true; defer { loading = false }

        let slugs = Array(stores.prefix(3)).map { offStoreSlug($0.name) }
        let base = (try? await search.search(query: q, country: countryHint, nearbyStoreSlugs: slugs)) ?? []
        results = stores.isEmpty ? base : ranker.rank(base, query: q, nearbyStores: stores)
    }
}
