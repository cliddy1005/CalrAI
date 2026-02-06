import SwiftUI

/// Root navigation view that switches between login and main app based on auth state.
struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.appEnvironment) private var env

    var body: some View {
        Group {
            switch auth.state {
            case .loggedOut:
                LoginView()
            case .offlineGuest, .loggedIn:
                DiaryView()
            }
        }
        .animation(.easeInOut, value: auth.state)
    }
}
