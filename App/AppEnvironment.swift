import Foundation
import CoreLocation
import SwiftUI

// Dependency container (very small on purpose)
struct AppEnvironment {
    let search: SearchService
    let location: LocationProvider

    static let live = AppEnvironment(
        search: OFFSearchService(),
        location: CoreLocationProvider()
    )
}

// EnvironmentKey to access AppEnvironment from any View
private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = .live
}
extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
