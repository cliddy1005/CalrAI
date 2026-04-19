import Foundation

protocol RemoteFoodClient {
    func lookupBarcode(_ code: String) async throws -> Food?
    func searchFoods(query: String, limit: Int) async throws -> [Food]
}

/// OpenFoodFacts client for barcode and text search.
struct OpenFoodFactsClient: RemoteFoodClient {
    private let base = "https://world.openfoodfacts.org"

    func lookupBarcode(_ code: String) async throws -> Food? {
        let url = URL(string: "\(base)/api/v2/product/\(code).json")!
        let resp: ProductResponse = try await fetch(url)
        guard let product = resp.product else { return nil }
        return product.toFood()
    }

    func searchFoods(query: String, limit: Int) async throws -> [Food] {
        var q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        q = q.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        if q.range(of: #"^\d{8,14}$"#, options: .regularExpression) != nil {
            if let food = try? await lookupBarcode(q) {
                return [food]
            }
        }

        var c = URLComponents(string: "\(base)/api/v2/search")!
        c.queryItems = [
            .init(name: "search_terms", value: q),
            .init(name: "page_size", value: String(max(1, min(limit, 50)))),
            .init(name: "sort_by", value: "unique_scans_n"),
            .init(name: "fields", value: "code,product_name,product_name_en,brands,quantity,nutriments,serving_size,image_url,countries_tags,last_updated_t,unique_scans_n"),
            .init(name: "languages_tags", value: langList())
        ]

        let resp: SearchResponse = try await fetch(c.url!)
        let foods = resp.products.map { $0.toFood() }
        return prioritizeUKUS(foods, tags: resp.products.map(\.countriesTags))
    }

    // MARK: - Helpers

    private func langList() -> String {
        if let code = Locale.current.language.languageCode?.identifier {
            return "\(code),en"
        }
        return "en"
    }

    private func prioritizeUKUS(_ foods: [Food], tags: [[String]?]) -> [Food] {
        var ukus: [Food] = []
        var rest: [Food] = []
        for (idx, food) in foods.enumerated() {
            if isUKUSTags(tags[idx]) {
                ukus.append(food)
            } else {
                rest.append(food)
            }
        }
        return ukus + rest
    }

    private func isUKUSTags(_ tags: [String]?) -> Bool {
        guard let tags else { return false }
        let lower = tags.map { $0.lowercased() }
        let needles = [
            "en:united-kingdom", "united-kingdom", "en:uk", "uk", "en:great-britain", "great-britain",
            "en:england", "england", "en:scotland", "scotland", "en:wales", "wales", "en:northern-ireland", "northern-ireland",
            "en:united-states", "united-states", "en:us", "us", "en:usa", "usa"
        ]
        return needles.contains { lower.contains($0) }
    }

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

// MARK: - API Models

private struct ProductResponse: Decodable {
    let product: OFFProduct?
}

private struct SearchResponse: Decodable {
    let products: [OFFProduct]
}

private struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let productNameEn: String?
    let brands: String?
    let nutriments: Nutriments?
    let servingSize: String?
    let imageUrl: String?
    let countriesTags: [String]?
    let quantity: String?
    let lastUpdated: Int?
    let uniqueScans: Int?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameEn = "product_name_en"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case imageUrl = "image_url"
        case countriesTags = "countries_tags"
        case quantity
        case lastUpdated = "last_updated_t"
        case uniqueScans = "unique_scans_n"
    }

    struct Nutriments: Decodable {
        let energyKcal100g: Double?
        let proteins100g: Double?
        let carbohydrates100g: Double?
        let fat100g: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case proteins100g = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fat100g = "fat_100g"
        }
    }

    func toFood() -> Food {
        let idValue = code?.trimmingCharacters(in: .whitespacesAndNewlines)
        let barcode = idValue?.isEmpty == false ? idValue! : UUID().uuidString
        let name = preferredName() ?? "Unnamed"
        let kcal = nutriments?.energyKcal100g ?? 0
        return Food(
            id: barcode,
            name: name,
            brand: brands,
            barcode: barcode,
            quantity: quantity,
            countriesTags: countriesTags,
            kcalPer100g: kcal,
            proteinPer100g: nutriments?.proteins100g,
            carbPer100g: nutriments?.carbohydrates100g,
            fatPer100g: nutriments?.fat100g,
            servingSizeGrams: extractServingGrams(servingSize),
            imageUrl: imageUrl,
            lastFetchedAt: Date(),
            popularity: uniqueScans,
            source: "openfoodfacts"
        )
    }

    private func preferredName() -> String? {
        let candidates = [productNameEn, productName, brands].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return candidates.first { !$0.isEmpty }
    }

    private func extractServingGrams(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        if let r = raw.range(of: #"(\d+(?:[.,]\d+)?)\s*(?:g|gram)"#, options: .regularExpression) {
            let num = raw[r].replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
            return Double(num.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}
