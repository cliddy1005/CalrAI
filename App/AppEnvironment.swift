import Foundation
import CoreLocation
import SwiftUI
import SwiftData

/// Dependency container for the app.
struct AppEnvironment {
    let search: SearchService
    let location: LocationProvider
    let localStore: LocalFoodStore
    let foodRepository: FoodRepository
    let modelContainer: ModelContainer

    @MainActor
    static let live: AppEnvironment = {
        let schema = Schema([CachedFood.self, DiaryEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let localStore = LocalFoodStore(container: container)
        let offSearch = OFFSearchService()
        let foodRepo = CachedFoodRepository(remote: offSearch, local: localStore)
        return AppEnvironment(
            search: offSearch,
            location: CoreLocationProvider(),
            localStore: localStore,
            foodRepository: foodRepo,
            modelContainer: container
        )
    }()

    /// Creates an in-memory environment for testing.
    @MainActor
    static func forTesting() -> AppEnvironment {
        let schema = Schema([CachedFood.self, DiaryEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let localStore = LocalFoodStore(container: container)
        let offSearch = OFFSearchService()
        let foodRepo = CachedFoodRepository(remote: offSearch, local: localStore)
        return AppEnvironment(
            search: offSearch,
            location: CoreLocationProvider(),
            localStore: localStore,
            foodRepository: foodRepo,
            modelContainer: container
        )
    }
}

// EnvironmentKey to access AppEnvironment from any View
private struct AppEnvironmentKey: EnvironmentKey {
    @MainActor static let defaultValue: AppEnvironment = .live
}
extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
