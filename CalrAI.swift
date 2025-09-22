//
//  CalrAI.swift
//  CalrAI  v1.2.1 (Improved search + auto barcode capture + init fixes)
//  iOS 17+, Xcode 15
//

import SwiftUI
import VisionKit

//────────────────────────────────────────────
// MARK: – Constants®
//────────────────────────────────────────────
fileprivate let kOFF = "https://world.openfoodfacts.org"
fileprivate let kUA  = "CalrAI-Demo/1.2.1"

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
        let bmr = sex == .male ? (10*w + 6.25*h - 5*a + 5)
                               : (10*w + 6.25*h - 5*a - 161)
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
    // Profile persistence
    @AppStorage("userProfile") private var stored = ""
    var profile: UserProfile {
        get { (try? JSONDecoder().decode(UserProfile.self, from: Data(stored.utf8))) ?? UserProfile() }
        set { stored = String(data: try! JSONEncoder().encode(newValue), encoding: .utf8)! }
    }
    
    // Meal buckets
    enum Meal: String, CaseIterable, Identifiable, Codable {
        case breakfast, lunch, dinner, snacks
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }
    
    // Log & UI
    @Published var entries: [FoodEntry] = []
    @Published var activeMeal: Meal?
    @Published var showScanner  = false
    @Published var showSearch   = false
    @Published var showSettings = false
    @Published var errorMessage: String?
    @Published var exerciseKcal = 0   // placeholder
    
    // CRUD
    func append(_ p: Product, to meal: Meal) {
        entries.append(.init(product: p, grams: p.servingSizeGrams ?? 100, meal: meal))
    }
    func delete(at offsets: IndexSet, in meal: Meal) {
        let slice = entriesFor(meal)
        let global = offsets.map { idx in entries.firstIndex(of: slice[idx])! }
        entries.remove(atOffsets: IndexSet(global))
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
        entries.reduce(into: (0,0,0)) { acc, e in
            acc.0 += e.protein; acc.1 += e.carbs; acc.2 += e.fat
        }
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
        
        // decode locals first
        let code = try p.decode(String.self, forKey: .code)
        let en  = try? p.decode(String.self, forKey: .product_name_en)
        let any = try? p.decode(String.self, forKey: .product_name)
        let brands = (try? p.decode(String.self, forKey: .brands))?
            .split(separator: ",").first?
            .trimmingCharacters(in: .whitespaces)
        
        // assign stored properties in safe order
        barcode = code
        
        // build name from locals, not self.*
        let computedName = [en, any, brands.map { "\($0) \(code)" }, "Unnamed"]
            .compactMap { $0 }
            .first!
            .trimmingCharacters(in: .whitespaces)
        name = computedName
        
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
    
    private enum K: String, CodingKey { case code, product_name_en, product_name, brands, nutriscore_grade, nutriments }
    private enum N: String, CodingKey { case energy_kcal_100g = "energy-kcal_100g" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        
        // locals first
        let code = try c.decode(String.self, forKey: .code)
        let en  = try? c.decode(String.self, forKey: .product_name_en)
        let any = try? c.decode(String.self, forKey: .product_name)
        let brands = (try? c.decode(String.self, forKey: .brands))?
            .split(separator: ",").first?
            .trimmingCharacters(in: .whitespaces)
        
        barcode = code
        
        let computedName = [en, any, brands, code]
            .compactMap { $0 }
            .first!
            .trimmingCharacters(in: .whitespaces)
        name = computedName
        
        nutriScore = try? c.decode(String.self, forKey: .nutriscore_grade)
        if let n = try? c.nestedContainer(keyedBy: N.self, forKey: .nutriments) {
            kcalPer100g = try n.decodeIfPresent(Double.self, forKey: .energy_kcal_100g)
        } else { kcalPer100g = nil }
    }
    
    // Allow manual construction (not just decoding)
    init(barcode: String, name: String, kcalPer100g: Double?, nutriScore: String?) {
        self.barcode = barcode
        self.name = name
        self.kcalPer100g = kcalPer100g
        self.nutriScore = nutriScore
    }
    init(from product: Product) {
        self.init(
            barcode: product.barcode,
            name: product.name,
            kcalPer100g: product.kcalPer100g,
            nutriScore: product.nutriScore
        )
    }
}

//────────────────────────────────────────────
// MARK: – Calorie banner
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
            metric("Goal", vm.goalKcal)
            Text("–")
            metric("Food", vm.totalKcal)
            Text("+")
            metric("Exercise", vm.exerciseKcal)
            Text("=")
            metric("Remaining", vm.remainingKcal, vm.remainingKcal >= 0 ? .green : .red)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

//────────────────────────────────────────────
// MARK: – Macro rings
//────────────────────────────────────────────
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
        switch g.kind {
        case .carbs:   return .teal
        case .fat:     return .purple
        case .protein: return .orange
        }
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
    
    private func actionRow(icon: String, text: String, meal: CalrAIVM.Meal,
                           trigger: @escaping () -> Void) -> some View {
        Button {
            vm.activeMeal = meal
            trigger()
        } label: {
            HStack { Image(systemName: icon); Text(text) }
        }
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
                                            Text(g.uppercased()).font(.caption2)
                                                .padding(4).background(Color.gray.opacity(0.2))
                                                .clipShape(Circle())
                                        }
                                    }
                                    Text("\(Int(e.grams)) g • \(Int(e.calories)) kcal")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { editing = e }
                            }
                            .onDelete { vm.delete(at: $0, in: meal) }
                            
                            actionRow(icon: "barcode.viewfinder", text: "Scan Barcode", meal: meal) {
                                vm.showScanner = true
                            }
                            actionRow(icon: "magnifyingglass", text: "Search Food", meal: meal) {
                                vm.showSearch = true
                            }
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
            .alert("Error",
                   isPresented: Binding(get: { vm.errorMessage != nil },
                                        set: { _ in vm.errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: { Text(vm.errorMessage ?? "") }
        }
    }
}

//────────────────────────────────────────────
// MARK: – Networking  (improved search)
//────────────────────────────────────────────
enum API {
    static func product(code: String) async throws -> Product {
        try await fetch(URL(string: "\(kOFF)/api/v2/product/\(code).json")!)
    }
    static func search(_ qRaw: String) async throws -> [ProductLite] {
        // Normalize query
        var q = qRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        q = q.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard q.count >= 2 else { return [] }
        
        // Use v2 search with simple mode + popularity sort
        var c = URLComponents(string: "\(kOFF)/api/v2/search")!
        let uiLang = Locale.current.language.languageCode?.identifier ?? "en"
        c.queryItems = [
            .init(name: "search_terms",    value: q),
            .init(name: "search_simple",   value: "1"),
            .init(name: "page_size",       value: "25"),
            .init(name: "sort_by",         value: "popularity_key"),
            .init(name: "languages_tags",  value: "\(uiLang),en"),
            .init(name: "fields",
                  value: "code,product_name_en,product_name,brands,nutriscore_grade,nutriments.energy-kcal_100g")
        ]
        struct Resp: Decodable { let products: [ProductLite] }
        let resp: Resp = try await fetch(c.url!)
        return resp.products.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    private static func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(kUA, forHTTPHeaderField: "User-Agent")
        let (d, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: d)
    }
}

//────────────────────────────────────────────
// MARK: – Search sheet
//────────────────────────────────────────────
struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    @State private var hits: [ProductLite] = []
    @State private var loading = false
    @State private var searchTask: Task<Void, Never>? = nil
    var pick: (Product) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if loading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
                ForEach(hits) { p in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(p.name)
                            if let g = p.nutriScore {
                                Text(g.uppercased())
                                    .font(.caption2)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                        if let kcal = p.kcalPer100g {
                            Text("\(Int(kcal)) kcal / 100 g")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await choose(p) } }
                }
                if !loading && hits.isEmpty && q.trimmingCharacters(in: .whitespaces).count >= 2 {
                    Text("No matches").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Search food")
            .searchable(text: $q, prompt: "Start typing…")
            .onChange(of: q) { newValue in
                searchTask?.cancel()
                searchTask = Task { await performSearch(for: newValue) }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", role: .cancel) { dismiss() } } }
        }
    }
    
    private func performSearch(for text: String) async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { hits = []; return }
        do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return } // cancelled
        
        // Barcode direct lookup if it looks like an EAN/UPC
        if query.range(of: #"^\d{8,14}$"#, options: .regularExpression) != nil {
            loading = true
            defer { loading = false }
            if let p = try? await API.product(code: query) {
                hits = [ProductLite(from: p)]
                return
            }
        }
        guard query.count >= 2 else { hits = []; return }
        loading = true
        defer { loading = false }
        guard !Task.isCancelled else { return }
        hits = (try? await API.search(query)) ?? []
    }
    
    private func choose(_ lite: ProductLite) async {
        if let p = try? await API.product(code: lite.barcode) { pick(p); dismiss() }
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
            recognizesMultipleItems: false, // only want first hit
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
        
        // Auto-capture when a new item appears
        func dataScanner(_ s: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didCapture else { return }
            if let code = addedItems.compactMap({ item -> String? in
                if case .barcode(let b) = item { return b.payloadStringValue }
                return nil
            }).first {
                didCapture = true
                parent.got(code)
                s.dismiss(animated: true)
            }
        }
        
        // Fallback: tap still works if needed
        func dataScanner(_ s: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard !didCapture else { return }
            if case .barcode(let b) = item, let code = b.payloadStringValue {
                didCapture = true
                parent.got(code)
                s.dismiss(animated: true)
            }
        }
    }
}

