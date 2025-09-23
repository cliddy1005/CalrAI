// Core/Services/OFFSearchService.swift
import Foundation

/// Open Food Facts implementation of SearchService
struct OFFSearchService: SearchService {
    private let base = "https://world.openfoodfacts.net"

    // MARK: - Product by barcode
    func product(code: String) async throws -> Product {
        let url = URL(string: "\(base)/api/v2/product/\(code).json")!
        return try await fetch(url)
    }

    // MARK: - Search
    func search(query: String, country: String?, nearbyStoreSlugs: [String]) async throws -> [ProductLite] {
        var q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse multiple spaces
        q = q.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // Barcode fast path
        if q.range(of: #"^\d{8,14}$"#, options: .regularExpression) != nil {
            if let p: Product = try? await product(code: q) {
                return [ProductLite(from: p)]
            }
        }

        var c = URLComponents(string: "\(base)/api/v2/search")!
        var items: [URLQueryItem] = [
            .init(name: "search_terms", value: q),
            .init(name: "page_size", value: "30"),
            .init(name: "sort_by", value: "unique_scans_n"),
            .init(name: "fields", value: "code,product_name_en,nutriscore_grade,nutriments.energy-kcal_100g"),
            .init(name: "languages_tags", value: langList())
        ]

        if let country = country {
            items.append(.init(name: "countries_tags", value: country.lowercased()))
        }
        if !nearbyStoreSlugs.isEmpty {
            items.append(.init(name: "stores_tags", value: nearbyStoreSlugs.joined(separator: ",")))
        }

        c.queryItems = items

        struct Resp: Decodable { let products: [ProductLite] }
        let resp: Resp = try await fetch(c.url!)
        return resp.products.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - Language list
    private func langList() -> String {
        if let code = Locale.current.language.languageCode?.identifier {
            return "\(code),en"
        } else {
            return "en"
        }
    }

    // MARK: - Networking
    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("CalrAI/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
