import Foundation

fileprivate let kOFF = "https://world.openfoodfacts.org"
fileprivate let kUA  = "CalrAI-Demo/1.5"

final class OFFSearchService: SearchService {
    func product(code: String) async throws -> Product {
        try await fetch(URL(string: "\\(kOFF)/api/v2/product/\\(code).json")!)
    }

    func search(query qRaw: String, country: String?, nearbyStoreSlugs: [String]) async throws -> [ProductLite] {
        var q = qRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        q = q.replacingOccurrences(of: #"\\s+"#, with: " ", options: .regular_expression)
        guard !q.isEmpty else { return [] }

        // barcode fast path
        if q.range(of: #"^\\d{8,14}$"#, options: .regular_expression) != nil {
            if let p: Product = try? await product(code: q) { return [ProductLite(from: p)] }
        }

        var c = URLComponents(string: "\\(kOFF)/api/v2/search")!
        var items: [URLQueryItem] = [
            .init(name: "search_terms",   value: q),
            .init(name: "search_simple",  value: "1"),
            .init(name: "languages_tags", value: langList()),
            .init(name: "page_size",      value: "80"),
            .init(name: "sort_by",        value: "popularity_key"),
            .init(name: "fields",         value: "code,product_name,brands,stores,unique_scans_n,nutriments.energy-kcal_100g"),
            .init(name: "nocache",        value: "1")
        ]
        if let country, !country.isEmpty { items.append(.init(name: "countries_tags_en", value: country)) }
        if !nearbyStoreSlugs.isEmpty {
            let or = nearbyStoreSlugs.joined(separator: "|")
            items.append(.init(name: "stores_tags_en", value: or))
            items.append(.init(name: "brands_tags_en", value: or))
        }
        c.queryItems = items

        struct Resp: Decodable { let products: [ProductLite] }
        let resp: Resp = try await fetch(c.url!)
        return resp.products
    }

    // MARK: helpers
    private func langList() -> String {
        let ui = Locale.current.language.languageCode?.identifier ?? "en"
        return "\\(ui),en"
    }
    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(kUA, forHTTPHeaderField: "User-Agent")
        let (d, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: d)
    }
}
