//
//  CalrAI.swift
//  CalrAI v1.5 (Location-aware search + nearby shops + own-label boost + auto barcode)
//  iOS 17+, Xcode 15
//

import SwiftUI
import VisionKit
import CoreLocation
import MapKit

//────────────────────────────────────────────
// MARK: – Constants®
//────────────────────────────────────────────
fileprivate let kOFF = "https://world.openfoodfacts.org"
fileprivate let kUA  = "CalrAI-Demo/1.5"

// Optionally helpful retailer names (used for proximity boost / slugging fallbacks)
fileprivate let kRetailerNames: [String] = [
    // UK / IE
    "Tesco","Sainsbury's","Sainsburys","Asda","Morrisons","Aldi","Lidl",
    "Co-op","Coop","Waitrose","Iceland","Marks & Spencer","M&S","Ocado","SuperValu","Dunnes",
    // Generic
    "Supermarket","Grocery"
]

//────────────────────────────────────────────
// MARK: – User profile & macro-calculator
//────────────────────────────────────────────
struct UserProfile: Codable {
    enum Sex: String, CaseIterable, Identifiable, Codable { case male, female; var id: Self { self } }
    enum Activity: String, CaseIterable, Identifiable, Codable {
        case sedentary, light, moderate, active, veryActive
        var factor: Double {
            switch self {
            case .sedentary:   1.2
            case .light:       1.375
            case .moderate:    1.55
            case .active:      1.725
            case .veryActive:  1.9
            }
        }
        var id: Self { self }
    }
    enum Goal: String, CaseIterable, Identifiable, Codable { case maintain, lose, gain; var id: Self { self } }
    
    var age = 30, sex = Sex.male
    var heightCm = 175, weightKg = 75
    var activity = Activity.moderate
    var goal = Goal.maintain
    
    func macroTargets() -> (kcal: Double, p: Double, f: Double, c: Double) {
        let w = Double(weightKg), h = Double(heightCm), a = Double(age)
        let bmr = sex == .male ? (10*w + 6.25*h - 5*a + 5) : (10*w + 6.25*h - 5*a - 161)
        var kcal = bmr * activity.factor
        if goal == .lose { kcal *= 0.85 }
        if goal == .gain { kcal *= 1.15 }
        let lb = w * 2.20462
        let pG = lb * 1.0
        let fG = lb * 0.4
        let cG = max(0, (kcal - pG*4 - fG*9) / 4)
        return (kcal.rounded(), pG.rounded(), fG.rounded(), cG.rounded())
    }
}

//────────────────────────────────────────────
// MARK: – App & global view-model
//────────────────────────────────────────────
@main
struct CalrAIApp: App {
    @StateObject private var vm = CalrAIVM()
    var body: some Scene { WindowGroup { RootView().environmentObject(vm) } }
}

@MainActor
final class CalrAIVM: ObservableObject {
    @AppStorage("userProfile") private var stored = ""
    var profile: UserProfile {
        get { (try? JSONDecoder().decode(UserProfile.self, from: Data(stored.utf8))) ?? UserProfile() }
        set { stored = String(data: try! JSONEncoder().encode(newValue), encoding: .utf8)! }
    }
    
    enum Meal: String, CaseIterable, Identifiable, Codable {
        case breakfast, lunch, dinner, snacks
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }
    
    @Published var entries: [FoodEntry] = []
    @Published var activeMeal: Meal?
    @Published var showScanner  = false
    @Published var showSearch   = false
    @Published var showSettings = false
    @Published var errorMessage: String?
    @Published var exerciseKcal = 0
    
    func append(_ p: Product, to meal: Meal) {
        entries.append(.init(product: p, grams: p.servingSizeGrams ?? 100, meal: meal))
    }
    func delete(at offsets: IndexSet, in meal: Meal) {
        let slice = entriesFor(meal)
        let global = offsets.compactMap { idx in entries.firstIndex(of: slice[idx]) }.sorted(by: >)
        for i in global { entries.remove(at: i) }
    }
    func update(id: UUID, grams: Double) {
        if let i = entries.firstIndex(where: { $0.id == id }) { entries[i].grams = grams }
    }
    func entriesFor(_ meal: Meal) -> [FoodEntry] { entries.filter { $0.meal == meal } }
    
    // Barcode → product
    func add(barcode: String) async {
        guard let m = activeMeal else { return }
        do { let p = try await API.product(code: barcode); append(p, to: m) }
        catch { errorMessage = error.localizedDescription }
    }
    
    // Totals & macro rings
    var totalKcal: Int { entries.reduce(0) { $0 + Int($1.calories) } }
    var totals: (p: Double, c: Double, f: Double) {
        entries.reduce(into: (0,0,0)) { acc, e in acc.0 += e.protein; acc.1 += e.carbs; acc.2 += e.fat }
    }
    var goalKcal: Int { Int(profile.macroTargets().kcal) }
    var remainingKcal: Int { goalKcal - totalKcal + exerciseKcal }
    var macroGoals: [MacroGoal] {
        let t = profile.macroTargets()
        return [
            .init(kind: .carbs,   eaten: totals.c, target: t.c),
            .init(kind: .fat,     eaten: totals.f, target: t.f),
            .init(kind: .protein, eaten: totals.p, target: t.p)
        ]
    }
}

//────────────────────────────────────────────
// MARK: – Data models
//────────────────────────────────────────────
struct FoodEntry: Identifiable, Hashable {
    let id = UUID()
    let product: Product
    var grams: Double
    let meal: CalrAIVM.Meal
    
    private func of(_ v: Double?) -> Double { (v ?? 0) * grams / 100 }
    var calories: Double { of(product.kcalPer100g) }
    var protein : Double { of(product.proteinPer100g) }
    var fat     : Double { of(product.fatPer100g) }
    var carbs   : Double { of(product.carbPer100g) }
}

struct Product: Decodable, Hashable {
    let barcode, name: String
    let kcalPer100g: Double
    let proteinPer100g, fatPer100g, carbPer100g: Double?
    let servingSizeGrams: Double?
    let nutriScore: String?
    
    private enum R: String, CodingKey { case product }
    private enum P: String, CodingKey { case code, product_name_en, product_name,
                                        serving_size, nutriscore_grade, nutriments, brands }
    private enum N: String, CodingKey { case energy_kcal_100g = "energy-kcal_100g",
                                        proteins_100g, fat_100g, carbohydrates_100g }
    init(from d: Decoder) throws {
        let r = try d.container(keyedBy: R.self)
        let p = try r.nestedContainer(keyedBy: P.self, forKey: .product)
        
        let code = try p.decode(String.self, forKey: .code)
        let en  = try? p.decode(String.self, forKey: .product_name_en)
        let any = try? p.decode(String.self, forKey: .product_name)
        let brands = try? p.decode(String.self, forKey: .brands)
        
        barcode = code
        var computedName: String
        if let en, !en.isEmpty { computedName = en }
        else if let any, !any.isEmpty { computedName = any }
        else if let brands, !brands.isEmpty { computedName = brands }
        else { computedName = "Unnamed" }
        name = computedName.trimmingCharacters(in: .whitespaces)
        
        nutriScore = try? p.decode(String.self, forKey: .nutriscore_grade)
        
        let n = try p.nestedContainer(keyedBy: N.self, forKey: .nutriments)
        kcalPer100g    = try n.decodeIfPresent(Double.self, forKey: .energy_kcal_100g) ?? 0
        proteinPer100g = try n.decodeIfPresent(Double.self, forKey: .proteins_100g)
        fatPer100g     = try n.decodeIfPresent(Double.self, forKey: .fat_100g)
        carbPer100g    = try n.decodeIfPresent(Double.self, forKey: .carbohydrates_100g)
        
        if let raw = try? p.decodeIfPresent(String.self, forKey: .serving_size) {
            servingSizeGrams = Product.extract(from: raw)
        } else { servingSizeGrams = nil }
    }
    private static func extract(from s: String) -> Double? {
        if let r = s.range(of: #"(\d+(?:[.,]\d+)?)\s*(?:g|gram)"#, options: .regularExpression) {
            let num = s[r].replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
            return Double(num.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}

struct ProductLite: Decodable, Identifiable {
    var id: String { barcode }
    let barcode, name: String
    let kcalPer100g: Double?
    let nutriScore: String?
    let brands: String?
    let stores: String?      // optional; OFF sometimes fills this
    let uniqueScans: Int?
    
    private enum K: String, CodingKey {
        case code, product_name_en, product_name, brands, stores, nutriscore_grade, nutriments, unique_scans_n
    }
    private enum N: String, CodingKey { case energy_kcal_100g = "energy-kcal_100g" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        let code = try c.decode(String.self, forKey: .code)
        let en  = try? c.decode(String.self, forKey: .product_name_en)
        let any = try? c.decode(String.self, forKey: .product_name)
        let brandsVal = try? c.decode(String.self, forKey: .brands)
        let storesVal = try? c.decode(String.self, forKey: .stores)
        
        barcode = code
        var computedName: String
        if let en, !en.isEmpty { computedName = en }
        else if let any, !any.isEmpty { computedName = any }
        else if let brandsVal, !brandsVal.isEmpty { computedName = brandsVal }
        else { computedName = code }
        name = computedName.trimmingCharacters(in: .whitespaces)
        
        nutriScore = try? c.decode(String.self, forKey: .nutriscore_grade)
        brands = brandsVal
        stores = storesVal
        uniqueScans = try? c.decode(Int.self, forKey: .unique_scans_n)
        
        if let n = try? c.nestedContainer(keyedBy: N.self, forKey: .nutriments) {
            kcalPer100g = try n.decodeIfPresent(Double.self, forKey: .energy_kcal_100g)
        } else { kcalPer100g = nil }
    }
    
    init(barcode: String, name: String, kcalPer100g: Double?, nutriScore: String?, brands: String?, stores: String?, uniqueScans: Int?) {
        self.barcode = barcode; self.name = name
        self.kcalPer100g = kcalPer100g; self.nutriScore = nutriScore
        self.brands = brands; self.stores = stores; self.uniqueScans = uniqueScans
    }
    init(from product: Product) {
        self.init(barcode: product.barcode, name: product.name, kcalPer100g: product.kcalPer100g, nutriScore: product.nutriScore, brands: nil, stores: nil, uniqueScans: nil)
    }
}

//────────────────────────────────────────────
// MARK: – Location services & nearby shops
//────────────────────────────────────────────
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?
    private let mgr = CLLocationManager()
    
    override init() {
        super.init()
        mgr.delegate = self
    }
    func request() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        mgr.requestWhenInUseAuthorization()
        mgr.startUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in self.status = status }
        if status == .authorizedWhenInUse || status == .authorizedAlways { manager.startUpdatingLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.location = last }
    }
}

struct Store: Identifiable, Hashable {
    var id: String { name + "\(Int(distanceMeters))" }
    let name: String
    let distanceMeters: Double
    var distanceString: String {
        let km = distanceMeters / 1000.0
        return km < 1 ? "\(Int(distanceMeters)) m" : String(format: "%.1f km", km)
    }
}

enum NearbyStoresService {
    static func find(around loc: CLLocation) async -> [Store] {
        let queries = kRetailerNames
        var found: [Store] = []
        for q in queries {
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = q
            req.region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
            let search = MKLocalSearch(request: req)
            if let resp = try? await search.start() {
                for item in resp.mapItems.prefix(6) {
                    let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Shop"
                    let d = item.placemark.location?.distance(from: loc) ?? .greatestFiniteMagnitude
                    found.append(Store(name: name, distanceMeters: d))
                }
            }
        }
        var best = [String: Store]()
        for s in found {
            if let prev = best[s.name] {
                if s.distanceMeters < prev.distanceMeters { best[s.name] = s }
            } else { best[s.name] = s }
        }
        return best.values.sorted { $0.distanceMeters < $1.distanceMeters }.prefix(12).map { $0 }
    }
}

func reverseGeocodeCountry(from loc: CLLocation) async -> String? {
    let geo = CLGeocoder()
    do {
        let placemarks = try await geo.reverseGeocodeLocation(loc)
        return placemarks.first?.country
    } catch { return nil }
}

// OFF slug helpers (convert “Sainsbury’s” → “sainsbury-s”)
fileprivate func offSlug(_ s: String) -> String {
    let lowered = s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    let replaced = lowered.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
    return replaced.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}
fileprivate let storeSlugOverrides: [String:String] = [
    "sainsbury's": "sainsbury-s",
    "m&s": "marks-and-spencer",
    "marks & spencer": "marks-and-spencer",
    "co-op": "the-co-operative",
    "coop": "the-co-operative"
]
fileprivate func offStoreSlug(_ name: String) -> String {
    let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return storeSlugOverrides[key] ?? offSlug(key)
}

//────────────────────────────────────────────
// MARK: – Calorie header & macro dashboard
//────────────────────────────────────────────
struct CalorieHeader: View {
    @EnvironmentObject var vm: CalrAIVM
    private func metric(_ t: String, _ v: Int, _ col: Color = .primary) -> some View {
        VStack(spacing: 1) {
            Text(t).font(.caption2).foregroundColor(.secondary)
            Text(v.formatted()).font(.footnote.weight(.semibold)).foregroundColor(col)
        }
    }
    var body: some View {
        HStack(spacing: 8) {
            metric("Goal", vm.goalKcal); Text("–")
            metric("Food", vm.totalKcal); Text("+")
            metric("Exercise", vm.exerciseKcal); Text("=")
            metric("Remaining", vm.remainingKcal, vm.remainingKcal >= 0 ? .green : .red)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

struct MacroGoal: Identifiable {
    enum Kind { case carbs, fat, protein }
    var id: Kind { kind }
    let kind: Kind
    let eaten, target: Double
    var remaining: Double { max(0, target - eaten) }
    var progress : Double { min(1, eaten / target) }
}
struct MacroRing: View {
    let g: MacroGoal
    private var col: Color {
        switch g.kind { case .carbs: .teal; case .fat: .purple; case .protein: .orange }
    }
    private var title: String {
        switch g.kind { case .carbs: "Carbs"; case .fat: "Fat"; case .protein: "Protein" }
    }
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.headline).foregroundStyle(col)
            ZStack {
                Circle().stroke(.gray.opacity(0.15), lineWidth: 14)
                Circle().trim(from: 0, to: g.progress)
                    .stroke(col, style: .init(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: g.progress)
                VStack(spacing: 0) {
                    Text(Int(g.eaten).formatted()).font(.title3).bold()
                    Text("/\(Int(g.target))g").font(.caption).foregroundColor(.secondary)
                }
            }.frame(width: 110, height: 110)
            Text("\(Int(g.remaining))g left").font(.caption).foregroundColor(.secondary)
        }
    }
}
struct MacroDashboard: View {
    @EnvironmentObject var vm: CalrAIVM
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 32) { ForEach(vm.macroGoals) { MacroRing(g: $0) } }
                .padding(.horizontal)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(.background).shadow(radius: 4))
        .padding(.horizontal)
    }
}

//────────────────────────────────────────────
// MARK: – Root view
//────────────────────────────────────────────
struct RootView: View {
    @EnvironmentObject private var vm: CalrAIVM
    @State private var editing: FoodEntry?
    
    private func actionRow(icon: String, text: String, meal: CalrAIVM.Meal, trigger: @escaping () -> Void) -> some View {
        Button {
            vm.activeMeal = meal
            trigger()
        } label: { HStack { Image(systemName: icon); Text(text) } }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalorieHeader()
                MacroDashboard()
                List {
                    ForEach(CalrAIVM.Meal.allCases) { meal in
                        Section(header: Text(meal.title)) {
                            ForEach(vm.entriesFor(meal)) { e in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(e.product.name)
                                        if let g = e.product.nutriScore {
                                            Text(g.uppercased())
                                                .font(.caption2)
                                                .padding(4)
                                                .background(Color.gray.opacity(0.2))
                                                .clipShape(Circle())
                                        }
                                    }
                                    Text("\(Int(e.grams)) g • \(Int(e.calories)) kcal")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { editing = e }
                            }
                            .onDelete { offsets in withAnimation { vm.delete(at: offsets, in: meal) } }
                            
                            actionRow(icon: "barcode.viewfinder", text: "Scan Barcode", meal: meal) { vm.showScanner = true }
                            actionRow(icon: "magnifyingglass", text: "Search Food", meal: meal) { vm.showSearch = true }
                        }
                    }
                }
            }
            .navigationTitle("Today \(vm.totalKcal) kcal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { vm.showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $vm.showScanner)  { ScannerSheet { code in Task { await vm.add(barcode: code) } } }
            .sheet(isPresented: $vm.showSearch)   { SearchSheet  { p in if let m = vm.activeMeal { vm.append(p, to: m) } } }
            .sheet(isPresented: $vm.showSettings) { SettingsSheet() }
            .sheet(item: $editing) { e in EditSheet(entry: e) { g in vm.update(id: e.id, grams: g) } }
            .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: { Text(vm.errorMessage ?? "") }
        }
    }
}

//────────────────────────────────────────────
// MARK: – Networking  (Location-aware search)
//────────────────────────────────────────────
enum API {
    // Product by barcode
    static func product(code: String) async throws -> Product {
        try await fetch(URL(string: "\(kOFF)/api/v2/product/\(code).json")!)
    }
    
    private static func baseFields() -> String {
        "code,product_name,brands,stores,unique_scans_n,nutriments.energy-kcal_100g"
    }
    private static func langList() -> String {
        let ui = Locale.current.language.languageCode?.identifier ?? "en"
        return "\(ui),en"
    }
    
    /// Location-aware search: biases by country + nearby stores/brands
    static func searchSmart(
        _ qRaw: String,
        countryHint: String?,
        nearbyStores: [Store]
    ) async throws -> [ProductLite] {
        var q = qRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        q = q.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard !q.isEmpty else { return [] }
        
        // Barcode direct path
        if q.range(of: #"^\d{8,14}$"#, options: .regularExpression) != nil {
            if let p: Product = try? await product(code: q) { return [ProductLite(from: p)] }
        }
        
        // Build OR lists from nearby store names (limit to 3 nearest)
        let topStores = Array(nearbyStores.prefix(3))
        let storeSlugs = topStores.map { offStoreSlug($0.name) }
        let brandSlugs = storeSlugs  // retailer own-label often matches brand
        
        var c = URLComponents(string: "\(kOFF)/api/v2/search")!
        var items: [URLQueryItem] = [
            .init(name: "search_terms",   value: q),
            .init(name: "search_simple",  value: "1"),
            .init(name: "languages_tags", value: langList()),
            .init(name: "page_size",      value: "80"),
            .init(name: "sort_by",        value: "popularity_key"),
            .init(name: "fields",         value: baseFields()),
            .init(name: "nocache",        value: "1")
        ]
        if let country = countryHint, !country.isEmpty {
            items.append(.init(name: "countries_tags_en", value: country))
        }
        if !storeSlugs.isEmpty {
            items.append(.init(name: "stores_tags_en", value: storeSlugs.joined(separator: "|")))
        }
        if !brandSlugs.isEmpty {
            items.append(.init(name: "brands_tags_en", value: brandSlugs.joined(separator: "|")))
        }
        c.queryItems = items
        
        struct Resp: Decodable { let products: [ProductLite] }
        let resp: Resp = try await fetch(c.url!)
        return resp.products
    }
    
    // Fetch helper
    private static func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(kUA, forHTTPHeaderField: "User-Agent")
        let (d, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: d)
    }
}

//────────────────────────────────────────────
// MARK: – Search ranking utils (nearby own-label boost)
//────────────────────────────────────────────
enum SearchRanker {
    static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
    static func popularityScore(_ n: Int?) -> Double {
        guard let n else { return 0 }
        return log(Double(n) + 1) / log(10.0)
    }
    static func brandOrStoreBoost(_ p: ProductLite, nearby: [Store], nearestOnly: Bool = true) -> Double {
        let names = (nearestOnly ? Array(nearby.prefix(1)) : nearby).map { norm($0.name) }
        let brand = norm(p.brands ?? "")
        let store = norm(p.stores ?? "")
        let hit = names.contains { brand.contains($0) || store.contains($0) }
        return hit ? 1.5 : 0.0
    }
    static func rank(results: [ProductLite], query: String, nearbyStores: [Store]) -> [ProductLite] {
        let qn = norm(query)
        return results.sorted { a, b in
            // Prefer items that match the nearest retailer brand/store
            let aBoost = brandOrStoreBoost(a, nearby: nearbyStores, nearestOnly: true)
            let bBoost = brandOrStoreBoost(b, nearby: nearbyStores, nearestOnly: true)
            if aBoost != bBoost { return aBoost > bBoost }
            
            // Then prefer name contains the query
            let aMatch = norm(a.name).contains(qn) ? 1 : 0
            let bMatch = norm(b.name).contains(qn) ? 1 : 0
            if aMatch != bMatch { return aMatch > bMatch }
            
            // Popularity as tie-breaker
            let aPop = popularityScore(a.uniqueScans)
            let bPop = popularityScore(b.uniqueScans)
            if aPop != bPop { return aPop > bPop }
            
            // Stable fallback
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}

//────────────────────────────────────────────
// MARK: – Search UI
//────────────────────────────────────────────
struct ProductRow: View {
    let product: ProductLite
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(product.name)
                if let g = product.nutriScore {
                    Text(g.uppercased())
                        .font(.caption2)
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            HStack(spacing: 8) {
                if let kcal = product.kcalPer100g { Text("\(Int(kcal)) kcal / 100 g") }
                if let brands = product.brands, !brands.isEmpty { Text(brands) }
                if let stores = product.stores, !stores.isEmpty { Text("at \(stores)") }
                if let scans = product.uniqueScans { Text("pop: \(scans)") }
            }
            .font(.caption).foregroundColor(.secondary)
        }
    }
}

struct ShopsStrip: View {
    let stores: [Store]
    var body: some View {
        if stores.isEmpty { EmptyView() }
        else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stores) { s in
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(s.name)
                            Text("· \(s.distanceString)").foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    }
                }.padding(.horizontal)
            }
            .padding(.vertical, 4)
        }
    }
}

struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    @State private var hits: [ProductLite] = []
    @State private var loading = false
    @State private var stores: [Store] = []
    @State private var countryHint: String?
    @State private var searchTask: Task<Void, Never>? = nil
    @StateObject private var loc = LocationService()
    var pick: (Product) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !stores.isEmpty { ShopsStrip(stores: stores) }
                else if loc.status == .denied || loc.status == .restricted {
                    Text("Location is off — showing global results.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
                }
                List {
                    if loading {
                        ProgressView().frame(maxWidth: .infinity, alignment: .center)
                    }
                    ForEach(hits) { p in
                        ProductRow(product: p)
                            .contentShape(Rectangle())
                            .onTapGesture { Task { await choose(p) } }
                    }
                    if !loading && hits.isEmpty && q.trimmingCharacters(in: .whitespaces).count >= 2 {
                        Text("No matches").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Search food")
            .searchable(text: $q, prompt: "Start typing…")
            .onChange(of: q) { newValue in
                searchTask?.cancel()
                searchTask = Task { await performSearch(for: newValue) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if loc.status == .notDetermined {
                        Button("Use Location") { loc.request() }
                    }
                }
            }
            .onAppear {
                if loc.status == .notDetermined { loc.request() }
                Task { await refreshGeoContext() }
            }
            .onChange(of: loc.location) { _ in Task { await refreshGeoContext() } }
        }
    }
    
    private func refreshGeoContext() async {
        guard let here = loc.location else { return }
        let nearby = await NearbyStoresService.find(around: here)
        await MainActor.run { self.stores = nearby }
        if let country = await reverseGeocodeCountry(from: here) {
            await MainActor.run { self.countryHint = country }
        }
    }
    
    private func performSearch(for text: String) async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { hits = []; return }
        do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return } // debounce
        guard !Task.isCancelled else { return }
        
        loading = true
        defer { loading = false }
        
        let base = (try? await API.searchSmart(query, countryHint: countryHint, nearbyStores: stores)) ?? []
        if stores.isEmpty {
            hits = base
        } else {
            hits = SearchRanker.rank(results: base, query: query, nearbyStores: stores)
        }
    }
    
    private func choose(_ lite: ProductLite) async {
        if let p = try? await API.product(code: lite.barcode) {
            pick(p); dismiss()
        }
    }
}

//────────────────────────────────────────────
// MARK: – Settings sheet
//────────────────────────────────────────────
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: CalrAIVM
    @State private var prof = UserProfile()
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal") {
                    Picker("Sex", selection: $prof.sex) {
                        ForEach(UserProfile.Sex.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Stepper("Age: \(prof.age)", value: $prof.age, in: 10 ... 80)
                    Stepper("Height: \(prof.heightCm) cm", value: $prof.heightCm, in: 120 ... 220)
                    Stepper("Weight: \(prof.weightKg) kg", value: $prof.weightKg, in: 30 ... 250)
                }
                Section("Lifestyle") {
                    Picker("Activity", selection: $prof.activity) {
                        ForEach(UserProfile.Activity.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Picker("Goal", selection: $prof.goal) {
                        ForEach(UserProfile.Goal.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }
                let t = prof.macroTargets()
                Section("Targets") {
                    Text("Energy  \(Int(t.kcal)) kcal")
                    Text("Protein \(Int(t.p)) g")
                    Text("Fat     \(Int(t.f)) g")
                    Text("Carbs   \(Int(t.c)) g")
                }
            }
            .navigationTitle("Your profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Save") { vm.profile = prof; dismiss() } }
                ToolbarItem(placement: .cancellationAction)  { Button("Cancel", role: .cancel) { dismiss() } }
            }
            .onAppear { prof = vm.profile }
        }
    }
}

//────────────────────────────────────────────
// MARK: – Edit sheet
//────────────────────────────────────────────
struct EditSheet: View {
    let entry: FoodEntry
    var save: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    enum Mode: String, CaseIterable, Identifiable { case grams, servings; var id: Self { self } }
    @State private var mode: Mode
    @State private var text: String
    
    init(entry: FoodEntry, save: @escaping (Double) -> Void) {
        self.entry = entry; self.save = save
        if let s = entry.product.servingSizeGrams {
            _mode = State(initialValue: .servings)
            _text = State(initialValue: String(format: "%.2f", entry.grams / s))
        } else {
            _mode = State(initialValue: .grams)
            _text = State(initialValue: String(Int(entry.grams)))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Unit", selection: $mode) {
                    Text("Grams").tag(Mode.grams)
                    if entry.product.servingSizeGrams != nil { Text("Servings").tag(Mode.servings) }
                }.pickerStyle(.segmented)
                TextField("Amount", text: $text).keyboardType(.decimalPad)
            }
            .navigationTitle("Edit")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit() }
                        .disabled(Double(text.replacingOccurrences(of: ",", with: ".")) == nil)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
            }
        }
    }
    private func commit() {
        guard var v = Double(text.replacingOccurrences(of: ",", with: ".")) else { return }
        if mode == .servings, let per = entry.product.servingSizeGrams { v *= per }
        save(max(1, v.rounded())); dismiss()
    }
}

//────────────────────────────────────────────
// MARK: – Barcode scanner wrapper (auto-capture)
//────────────────────────────────────────────
struct ScannerSheet: UIViewControllerRepresentable {
    var got: (String) -> Void
    func makeCoordinator() -> Coord { Coord(self) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }
    func updateUIViewController(_ ui: DataScannerViewController, context: Context) {}
    final class Coord: NSObject, DataScannerViewControllerDelegate {
        let parent: ScannerSheet
        private var didCapture = false
        init(_ p: ScannerSheet) { parent = p }
        func dataScanner(_ s: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didCapture else { return }
            if let code = addedItems.compactMap({ item -> String? in
                if case .barcode(let b) = item { return b.payloadStringValue }; return nil
            }).first {
                didCapture = true; parent.got(code); s.dismiss(animated: true)
            }
        }
        func dataScanner(_ s: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard !didCapture else { return }
            if case .barcode(let b) = item, let code = b.payloadStringValue {
                didCapture = true; parent.got(code); s.dismiss(animated: true)
            }
        }
    }
}

