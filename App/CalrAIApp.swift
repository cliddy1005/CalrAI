import SwiftUI

@main
struct CalrAIApp: App {
    let env = AppEnvironment.live

    var body: some Scene {
        WindowGroup {
            DiaryView()
                .environment(\.appEnvironment, env)
        }
    }
}
