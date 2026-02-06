import Foundation
import SwiftUI

/// Authentication state controlling the app's navigation flow.
enum AuthState: Equatable {
    case loggedOut
    case offlineGuest
    case loggedIn(username: String)
}

/// Manages authentication state. Supports local accounts stored in Keychain.
/// Designed to be upgradeable to Sign in with Apple / cloud sync later.
@MainActor
final class AuthManager: ObservableObject {
    @Published var state: AuthState = .loggedOut

    private static let usernameKey = "calrai_username"
    private static let pinKey = "calrai_pin"
    private static let sessionKey = "calrai_session"

    init() {
        restoreSession()
    }

    // MARK: - Session Persistence

    private func restoreSession() {
        if let session = KeychainService.loadString(forKey: Self.sessionKey) {
            if session == "__offline_guest__" {
                state = .offlineGuest
            } else {
                state = .loggedIn(username: session)
            }
        }
    }

    private func persistSession(_ value: String) {
        KeychainService.saveString(value, forKey: Self.sessionKey)
    }

    private func clearSession() {
        KeychainService.delete(key: Self.sessionKey)
    }

    // MARK: - Actions

    /// Create a new local account with username + PIN.
    func createAccount(username: String, pin: String) -> Bool {
        let userKey = "pin_\(username.lowercased())"
        guard KeychainService.loadString(forKey: userKey) == nil else {
            return false // Username already exists
        }
        KeychainService.saveString(pin, forKey: userKey)
        state = .loggedIn(username: username)
        persistSession(username)
        return true
    }

    /// Login with username + PIN.
    func login(username: String, pin: String) -> Bool {
        let userKey = "pin_\(username.lowercased())"
        guard let storedPin = KeychainService.loadString(forKey: userKey),
              storedPin == pin else {
            return false
        }
        state = .loggedIn(username: username)
        persistSession(username)
        return true
    }

    /// Continue as offline guest (no account required).
    func continueOffline() {
        state = .offlineGuest
        persistSession("__offline_guest__")
    }

    /// Logout and clear session.
    func logout() {
        state = .loggedOut
        clearSession()
    }

    /// Current username for display (nil for guest/logged out).
    var currentUsername: String? {
        if case .loggedIn(let username) = state { return username }
        return nil
    }

    /// Whether the user is in offline guest mode.
    var isGuest: Bool {
        state == .offlineGuest
    }

    /// Whether the user has any active session (logged in or guest).
    var hasSession: Bool {
        state != .loggedOut
    }
}
