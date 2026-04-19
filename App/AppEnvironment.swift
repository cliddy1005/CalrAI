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
        let container: ModelContainer
        do {
            container = try ModelContainer(for: CachedFood.self, DiaryEntry.self)
        } catch {
            print("[AppEnvironment] Persistent ModelContainer failed: \(error). Falling back to in-memory.")
            let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: CachedFood.self, DiaryEntry.self,
                                              configurations: inMemory)
            } catch {
                fatalError("[AppEnvironment] SwiftData schema is broken and cannot be loaded: \(error)")
            }
        }
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
        let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: CachedFood.self, DiaryEntry.self,
                                           configurations: inMemory)
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
    nonisolated(unsafe) static let defaultValue: AppEnvironment = MainActor.assumeIsolated { .live }
}
extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
