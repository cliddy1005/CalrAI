import Foundation
import SwiftUI
import CoreLocation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [ProductLite] = []
    @Published var loading: Bool = false
    @Published var nearbyStores: [Store] = []
    @Published var countryHint: String?

    private var searchTask: Task<Void, Never>? = nil

    // Run the search with injected environment
    func performSearch(using env: AppEnvironment) async {
        // Cancel any ongoing search task (debounce)
        searchTask?.cancel()

        searchTask = Task { [weak self] in
            guard let self else { return }

            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else {
                self.results = []
                return
            }

            self.loading = true
            defer { self.loading = false }

            do {
                // Get top 3 store slugs from nearby stores
                let slugs = Array(self.nearbyStores.prefix(3)).map { offStoreSlug($0.name) }

                // Fetch base results from API
                let base = try await env.search.search(
                    query: trimmed,
                    country: countryHint,
                    nearbyStoreSlugs: slugs
                )

                // Rank them by store + query relevance
                self.results = SearchRanker.live.rank(base, query: trimmed, nearbyStores: self.nearbyStores)

            } catch {
                print("❌ Search error: \(error.localizedDescription)")
                self.results = []
            }
        }
    }
}

