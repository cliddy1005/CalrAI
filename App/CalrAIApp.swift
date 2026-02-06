import SwiftUI
import SwiftData

@main
struct CalrAIApp: App {
    let env = AppEnvironment.live
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appEnvironment, env)
                .environmentObject(auth)
                .modelContainer(env.modelContainer)
        }
    }
}
