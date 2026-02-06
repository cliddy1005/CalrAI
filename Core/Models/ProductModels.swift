import Foundation

struct Product: Decodable, Hashable {
    let barcode, name: String
    let kcalPer100g: Double
    let proteinPer100g, fatPer100g, carbPer100g: Double?
    let servingSizeGrams: Double?
    let nutriScore: String?

    private enum R: String, CodingKey { case product }
    private enum P: String, CodingKey { case code, product_name_en, product_name, serving_size, nutriscore_grade, nutriments, brands }
    private enum N: String, CodingKey { case energy_kcal_100g = "energy-kcal_100g", proteins_100g, fat_100g, carbohydrates_100g }

    init(from d: Decoder) throws {
        let r = try d.container(keyedBy: R.self)
        let p = try r.nestedContainer(keyedBy: P.self, forKey: .product)

        let code = try p.decode(String.self, forKey: .code)
        let en  = try? p.decode(String.self, forKey: .product_name_en)
        let any = try? p.decode(String.self, forKey: .product_name)
        let brands = try? p.decode(String.self, forKey: .brands)

        barcode = code
        let nm = [en, any, brands, "Unnamed"].compactMap { $0 }.first(where: { !$0.isEmpty })!
        name = nm.trimmingCharacters(in: .whitespaces)

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

    /// Memberwise initializer for building from cached data.
    init(barcode: String, name: String, kcalPer100g: Double,
         proteinPer100g: Double?, fatPer100g: Double?, carbPer100g: Double?,
         servingSizeGrams: Double?, nutriScore: String?) {
        self.barcode = barcode
        self.name = name
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbPer100g = carbPer100g
        self.servingSizeGrams = servingSizeGrams
        self.nutriScore = nutriScore
    }
}

struct ProductLite: Decodable, Identifiable {
    var id: String { barcode }
    let barcode, name: String
    let kcalPer100g: Double?
    let nutriScore: String?
    let brands: String?
    let stores: String?
    let uniqueScans: Int?

    private enum K: String, CodingKey { case code, product_name_en, product_name, brands, stores, nutriscore_grade, nutriments, unique_scans_n }
    private enum N: String, CodingKey { case energy_kcal_100g = "energy-kcal_100g" }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        let code = try c.decode(String.self, forKey: .code)
        let en  = try? c.decode(String.self, forKey: .product_name_en)
        let any = try? c.decode(String.self, forKey: .product_name)
        let brandsVal = try? c.decode(String.self, forKey: .brands)
        let storesVal = try? c.decode(String.self, forKey: .stores)

        barcode = code
        let nm = [en, any, brandsVal, code].compactMap { $0 }.first(where: { !$0.isEmpty })!
        name = nm.trimmingCharacters(in: .whitespaces)

        nutriScore = try? c.decode(String.self, forKey: .nutriscore_grade)
        brands = brandsVal
        stores = storesVal
        uniqueScans = try? c.decode(Int.self, forKey: .unique_scans_n)

        if let n = try? c.nestedContainer(keyedBy: N.self, forKey: .nutriments) {
            kcalPer100g = try n.decodeIfPresent(Double.self, forKey: .energy_kcal_100g)
        } else { kcalPer100g = nil }
    }

    init(from product: Product) {
        self.init(barcode: product.barcode, name: product.name, kcalPer100g: product.kcalPer100g, nutriScore: product.nutriScore, brands: nil, stores: nil, uniqueScans: nil)
    }

    init(barcode: String, name: String, kcalPer100g: Double?, nutriScore: String?, brands: String?, stores: String?, uniqueScans: Int?) {
        self.barcode = barcode; self.name = name
        self.kcalPer100g = kcalPer100g; self.nutriScore = nutriScore
        self.brands = brands; self.stores = stores; self.uniqueScans = uniqueScans
    }
}
