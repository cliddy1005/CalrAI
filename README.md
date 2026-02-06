# CalrAI

Open source iOS calorie tracking app with barcode scanner, offline support, and local persistence.

## Features

- **Barcode scanning** via VisionKit DataScanner
- **Food search** powered by Open Food Facts API
- **Offline-first food lookup** with local caching
- **Diary persistence** across app sessions via SwiftData
- **History view** with calendar date picker and weekly stats
- **Local login** with Keychain-secured PIN accounts
- **Custom food entries** for items not in the database
- **Macro tracking** with visual ring progress indicators

## Architecture

```
App/            CalrAIApp (entry point), AppEnvironment (DI container)
Core/
  Models/       Product, ProductLite, CachedFood, DiaryEntry, FoodEntry, UserProfile
  Services/     SearchService, OFFSearchService, FoodRepository, CachedFoodRepository,
                LocalFoodStore, AuthManager, KeychainService
  Utilities/    SearchRanker, OFFSlug
Features/
  Auth/         LoginView, CreateAccountView, RootView
  Diary/        DiaryView, DiaryViewModel, EditSheet, MacroRing
  History/      HistoryView (calendar + stats)
  Scanner/      ScannerSheet
  Search/       SearchView, SearchViewModel, ProductRow, CustomFoodView
  Settings/     SettingsView
```

## Offline Lookup Design

The app uses a three-layer architecture for food data:

1. **RemoteFoodService** (`OFFSearchService`) - Calls Open Food Facts API for fresh data
2. **LocalFoodStore** - SwiftData persistence for cached foods and diary entries
3. **CachedFoodRepository** - Orchestrator that:
   - For **barcode lookup**: tries remote first, caches result; falls back to local cache if offline
   - For **search**: fetches local + remote results, merges them, caches remote results
   - If offline and barcode unknown: throws `FoodLookupError.notFoundOffline` which triggers the custom food entry UI

All foods ever fetched online are cached locally (by barcode as unique key). Search results from the API are also cached. This means:
- Previously scanned barcodes work offline
- Previously searched foods appear in offline search results
- Custom foods created offline are stored permanently

## Data Storage

**SwiftData** (iOS 17+) with two `@Model` classes:

| Model | Purpose |
|-------|---------|
| `CachedFood` | Offline food cache (barcode, name, nutrition, brands, stores) |
| `DiaryEntry` | Diary entries (date, meal, food, grams, macro snapshots, notes) |

The `ModelContainer` is configured in `AppEnvironment` and shared via SwiftUI environment.

### Schema Versioning

SwiftData supports lightweight migration automatically. The models use `@Attribute(.unique)` for barcode deduplication. For future schema changes:
- Add new optional properties (automatic lightweight migration)
- For breaking changes, use `VersionedSchema` and `SchemaMigrationPlan`

### Resetting the Local Database (Dev)

Delete the app from the simulator/device, or call `LocalFoodStore.deleteAllData()` from the Settings view's "Reset Local Database" button.

Programmatically in tests, use an in-memory container:
```swift
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
```

## Login / Offline Mode

The app supports three auth states:

| State | Access | Storage |
|-------|--------|---------|
| **Logged Out** | LoginView only | - |
| **Continue Offline** | Full app, guest profile | Local only |
| **Logged In** | Full app, named profile | Keychain + local |

### How it works

- `AuthManager` publishes an `AuthState` enum that drives `RootView` navigation
- Local accounts use username + PIN stored securely in iOS Keychain via `KeychainService`
- Sessions persist across app launches (stored in Keychain)
- "Continue Offline" creates a local guest session - no account needed
- Designed for future upgrade to Sign in with Apple / cloud sync without re-architecture

### Flow

```
App Launch → AuthManager.restoreSession()
  ├─ Has session → Main App (DiaryView)
  └─ No session → LoginView
       ├─ Log In → validates PIN → Main App
       ├─ Create Account → stores in Keychain → Main App
       └─ Continue Offline → guest session → Main App
```

## Requirements

- iOS 18.0+
- Xcode 16.0+
- No third-party dependencies (pure Apple frameworks)

## Testing

Run tests via Xcode or `xcodebuild test`:

- `FoodCacheTests` - Verifies food cached online is available offline (save, lookup, search, upsert, round-trip)
- `DiaryPersistenceTests` - Verifies diary entry CRUD (insert, fetch by date, delete, edit, date range queries, manual entries)

All tests use in-memory SwiftData containers for isolation.
