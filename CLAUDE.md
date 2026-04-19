# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build the main app
xcodebuild build -scheme CalrAI -project CalrAI.xcodeproj

# Run all tests (unit + UI)
xcodebuild test -scheme CalrAI -destination 'platform=iOS Simulator,name=iPhone 16'

# Build widget extension
xcodebuild build -scheme CalrAIMacrosWidgetExtension -project CalrAI.xcodeproj

# List all schemes
xcodebuild -list -project CalrAI.xcodeproj
```

No Package.swift, Makefile, or linter config exists — pure Xcode project only.

## Architecture Overview

CalrAI is an iOS 18+ SwiftUI calorie tracking app using **no third-party dependencies** — only Apple frameworks (SwiftData, VisionKit, CoreLocation, WidgetKit).

### Layer Structure

```
App/          – Entry point (CalrAIApp.swift) + DI container (AppEnvironment.swift)
Core/         – Models, Services, Utilities (no UI code)
Features/     – SwiftUI views + ViewModels, one folder per feature
CalrAIMacrosWidget/  – WidgetKit lock screen widget extension
CalrAITests/  – Unit tests using Swift Testing (not XCTest)
```

### Dependency Injection

`AppEnvironment` is a struct that holds all live service instances. It is injected via a custom SwiftUI `EnvironmentKey` and accessed with `@Environment(\.appEnvironment)`. Tests use `AppEnvironment.forTesting()` which wires in-memory SwiftData containers. Do not instantiate services directly in views — always pull from the environment.

### Food Data Flow (Three-Layer)

`CachedFoodRepository` orchestrates all food lookups:
1. **Remote**: `OFFSearchService` → Open Food Facts API v2
2. **Cache/Persist**: `LocalFoodStore` → SwiftData (`CachedFood` model)
3. **Fallback**: returns local-only results when offline; throws `FoodLookupError.notFoundOffline` for unknown barcodes offline → UI should offer custom food entry

### SwiftData Models

Two `@Model` types in a single container:
- `CachedFood` – offline food cache; barcode has `@Attribute(.unique)`
- `DiaryEntry` – logged meals with macro snapshots per serving

Both models use `isStoredInMemoryOnly: true` containers in tests.

### Authentication

`AuthManager` manages an `AuthState` enum (`loggedOut`, `offlineGuest`, `loggedIn`). Sessions are persisted via `KeychainService`. `RootView` switches the entire navigation tree based on this state.

### MVVM Pattern

- ViewModels: `DiaryViewModel`, `SearchViewModel` — held as `@StateObject` in root views
- `@Published` properties drive all reactive updates
- User profile is JSON-encoded into `@AppStorage` (UserDefaults)

### Logging

`AppLog.swift` wraps `os.Logger` with per-category loggers (`db.query`, `ui.search`, etc.). Debug DB logs can be enabled at runtime: `UserDefaults.standard.set(true, forKey: "DEBUG_DB_LOGS")`.

## Tests

Tests use the **Swift Testing** framework (`@Test`, `#expect`). Two suites:
- `FoodCacheTests` – save/lookup/search/upsert round-trips for `CachedFood`
- `DiaryPersistenceTests` – insert/fetch/delete/edit/date-range for `DiaryEntry`

All tests create their own in-memory `ModelContainer` for isolation.
