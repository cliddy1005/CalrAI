import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class LocalFoodDatabase {
    enum LoadError: Error {
        case missingDatabase
        case openFailed
    }

    private let db: OpaquePointer?
    let url: URL

    init(url: URL) throws {
        self.url = url
        var handle: OpaquePointer?
        AppLog.log(AppLog.dbOpen, "sqlite3_open_v2 path=\(url.path) flags=READONLY")
        if sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            let err = handle.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
            AppLog.warn(AppLog.dbOpen, "open failed: \(err)")
            sqlite3_close(handle)
            throw LoadError.openFailed
        }
        db = handle
#if DEBUG
        debugLogOpen(path: url.path)
        debugHealthCheck()
#endif
    }

    deinit {
        sqlite3_close(db)
    }

    static func bundled() throws -> LocalFoodDatabase {
        let resource = "offline_foods"
        let ext = "sqlite"
        AppLog.log(AppLog.dbBundle, "bundle lookup resource=\(resource).\(ext)")
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            AppLog.warn(AppLog.dbBundle, "bundle lookup failed: nil url")
            throw LoadError.missingDatabase
        }
        let path = url.path
        let exists = FileManager.default.fileExists(atPath: path)
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let mod = (attrs?[.modificationDate] as? Date)?.description ?? "unknown"
        AppLog.log(AppLog.dbBundle, "bundle path=\(path) exists=\(exists) size=\(size) modified=\(mod)")
        AppLog.log(AppLog.dbCopy, "using bundled DB directly (read-only); no copy step")
        return try LocalFoodDatabase(url: url)
    }

    static func emptyTemp() throws -> LocalFoodDatabase {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("offline_foods_empty.sqlite")
        if !FileManager.default.fileExists(atPath: url.path) {
            var handle: OpaquePointer?
            if sqlite3_open(url.path, &handle) == SQLITE_OK {
                sqlite3_exec(handle, """
                CREATE TABLE IF NOT EXISTS foods (
                    barcode TEXT PRIMARY KEY,
                    product_name TEXT,
                    brands TEXT,
                    quantity TEXT,
                    countries_tags TEXT,
                    energy_kcal_100g REAL,
                    proteins_100g REAL,
                    carbohydrates_100g REAL,
                    fat_100g REAL,
                    serving_size TEXT,
                    image_url TEXT,
                    last_updated_t INTEGER,
                    popularity INTEGER,
                    source TEXT
                );
                """, nil, nil, nil)
                sqlite3_exec(handle, "CREATE VIRTUAL TABLE IF NOT EXISTS foods_fts USING fts5(product_name, brands, content='foods', content_rowid='rowid');", nil, nil, nil)
            }
            sqlite3_close(handle)
        }
        return try LocalFoodDatabase(url: url)
    }

    func lookupBarcode(_ code: String) -> Food? {
        let start = Date()
        AppLog.log(AppLog.dbQuery, "lookupBarcode code=\(code)")
        let sql = """
        SELECT barcode, product_name, brands, quantity, countries_tags,
               energy_kcal_100g, proteins_100g, carbohydrates_100g, fat_100g,
               serving_size, image_url, last_updated_t, popularity, source
        FROM foods WHERE barcode = ? LIMIT 1;
        """
        let result = querySingle(sql: sql, bind: { sqlite3_bind_text($0, 1, code, -1, SQLITE_TRANSIENT) })
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        AppLog.log(AppLog.dbQuery, "lookupBarcode result=\(result == nil ? "miss" : "hit") timeMs=\(ms)")
        return result
    }

    func searchFoods(query: String, limit: Int) -> [Food] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let start = Date()
        AppLog.log(AppLog.dbQuery, "search query=\(trimmed) limit=\(limit)")

        if hasFTS() {
            let ftsQuery = buildFTSQuery(from: trimmed)
            AppLog.log(AppLog.dbFTS, "fts query=\(ftsQuery)")
            let sql = """
            SELECT f.barcode, f.product_name, f.brands, f.quantity, f.countries_tags,
                   f.energy_kcal_100g, f.proteins_100g, f.carbohydrates_100g, f.fat_100g,
                   f.serving_size, f.image_url, f.last_updated_t, f.popularity, f.source
            FROM foods_fts
            JOIN foods f ON f.rowid = foods_fts.rowid
            WHERE foods_fts MATCH ?
            ORDER BY f.popularity DESC
            LIMIT ?;
            """
            let ftsResults = queryMany(sql: sql, bind: {
                sqlite3_bind_text($0, 1, ftsQuery, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int($0, 2, Int32(limit))
            })
            if !ftsResults.isEmpty {
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                AppLog.log(AppLog.dbQuery, "search strategy=FTS results=\(ftsResults.count) timeMs=\(ms)")
                return ftsResults
            } else {
                AppLog.log(AppLog.dbFTS, "fts returned 0; falling back to LIKE")
            }
        }
        let sql = """
        SELECT barcode, product_name, brands, quantity, countries_tags,
               energy_kcal_100g, proteins_100g, carbohydrates_100g, fat_100g,
               serving_size, image_url, last_updated_t, popularity, source
        FROM foods
        WHERE product_name LIKE ? OR brands LIKE ?
        ORDER BY popularity DESC
        LIMIT ?;
        """
        let like = "%\(trimmed)%"
        let results = queryMany(sql: sql, bind: {
            sqlite3_bind_text($0, 1, like, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text($0, 2, like, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int($0, 3, Int32(limit))
        })
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        AppLog.log(AppLog.dbQuery, "search strategy=LIKE results=\(results.count) timeMs=\(ms)")
        if results.isEmpty {
            let ftsCount = countRows(table: "foods_fts") ?? -1
            let foodsCount = countRows(table: "foods") ?? -1
            AppLog.warn(AppLog.dbQuery, "0 results; foods=\(foodsCount) fts=\(ftsCount)")
        }
        return results
    }

    private func hasFTS() -> Bool {
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name='foods_fts' LIMIT 1;"
        let results = queryMany(sql: sql, bind: nil)
        return !results.isEmpty
    }

    private func querySingle(sql: String, bind: ((OpaquePointer) -> Void)?) -> Food? {
        let results = queryMany(sql: sql, bind: bind)
        return results.first
    }

    private func queryMany(sql: String, bind: ((OpaquePointer) -> Void)?) -> [Food] {
        var stmt: OpaquePointer?
        var foods: [Food] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let err = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
            AppLog.warn(AppLog.dbQuery, "prepare failed: \(err)")
            sqlite3_finalize(stmt)
            return []
        }
        if let bind { bind(stmt!) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            foods.append(mapRow(stmt!))
        }
        if sqlite3_finalize(stmt) != SQLITE_OK {
            AppLog.warn(AppLog.dbQuery, "finalize failed")
        }
        return foods
    }

    private func mapRow(_ stmt: OpaquePointer) -> Food {
        let barcode = string(stmt, 0)
        let name = string(stmt, 1)
        let brands = stringOpt(stmt, 2)
        let quantity = stringOpt(stmt, 3)
        let countries = stringOpt(stmt, 4)
        let kcal = double(stmt, 5)
        let protein = doubleOpt(stmt, 6)
        let carbs = doubleOpt(stmt, 7)
        let fat = doubleOpt(stmt, 8)
        let serving = stringOpt(stmt, 9)
        let imageUrl = stringOpt(stmt, 10)
        let lastUpdated = intOpt(stmt, 11).map { Date(timeIntervalSince1970: TimeInterval($0)) }
        let popularity = intOpt(stmt, 12)
        let source = stringOpt(stmt, 13)

        return Food(
            id: barcode,
            name: name,
            brand: brands,
            barcode: barcode,
            quantity: quantity,
            countriesTags: countries?.split(separator: ",").map { String($0) },
            kcalPer100g: kcal,
            proteinPer100g: protein,
            carbPer100g: carbs,
            fatPer100g: fat,
            servingSizeGrams: serving.flatMap { extractServingGrams($0) },
            imageUrl: imageUrl,
            lastFetchedAt: lastUpdated,
            popularity: popularity,
            source: source ?? "offline_db"
        )
    }

    private func string(_ stmt: OpaquePointer, _ idx: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, idx) else { return "" }
        return String(cString: c)
    }

    private func stringOpt(_ stmt: OpaquePointer, _ idx: Int32) -> String? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL else { return nil }
        return string(stmt, idx)
    }

    private func double(_ stmt: OpaquePointer, _ idx: Int32) -> Double {
        sqlite3_column_double(stmt, idx)
    }

    private func doubleOpt(_ stmt: OpaquePointer, _ idx: Int32) -> Double? {
        sqlite3_column_type(stmt, idx) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, idx)
    }

    private func intOpt(_ stmt: OpaquePointer, _ idx: Int32) -> Int? {
        sqlite3_column_type(stmt, idx) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, idx))
    }

    private func extractServingGrams(_ raw: String) -> Double? {
        if let r = raw.range(of: #"(\d+(?:[.,]\d+)?)\s*(?:g|gram)"#, options: .regularExpression) {
            let num = raw[r].replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
            return Double(num.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    private func buildFTSQuery(from raw: String) -> String {
        let tokens = raw
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.filter { $0.isLetter || $0.isNumber } }
            .filter { !$0.isEmpty }
        if tokens.isEmpty { return raw }
        return tokens.map { "\($0)*" }.joined(separator: " ")
    }

    struct DebugReport {
        let path: String
        let exists: Bool
        let fileSize: Int64?
        let tables: [String]
        let foodsCount: Int?
        let foodsFTSCount: Int?
        let sampleResults: [Food]
    }

    func debugReport(sampleQuery: String = "milk") -> DebugReport {
        let path = url.path
        let exists = FileManager.default.fileExists(atPath: path)
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let fileSize = (attrs?[.size] as? NSNumber)?.int64Value
        let tables = tableNames()
        let foodsCount = countRows(table: "foods")
        let foodsFTSCount = tables.contains("foods_fts") ? countRows(table: "foods_fts") : nil
        let sampleResults = searchFoods(query: sampleQuery, limit: 10)
        return DebugReport(
            path: path,
            exists: exists,
            fileSize: fileSize,
            tables: tables,
            foodsCount: foodsCount,
            foodsFTSCount: foodsFTSCount,
            sampleResults: sampleResults
        )
    }

    private func tableNames() -> [String] {
        let sql = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
        var stmt: OpaquePointer?
        var names: [String] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            sqlite3_finalize(stmt)
            return []
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) {
                names.append(String(cString: c))
            }
        }
        sqlite3_finalize(stmt)
        return names
    }

    private func countRows(table: String) -> Int? {
        let sql = "SELECT COUNT(*) FROM \(table);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            sqlite3_finalize(stmt)
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return nil
    }

#if DEBUG
    private func debugLogOpen(path: String) {
        let exists = FileManager.default.fileExists(atPath: path)
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        AppLog.log(AppLog.dbOpen, "open path=\(path) exists=\(exists) size=\(size)")
    }

    private func debugHealthCheck() {
        AppLog.log(AppLog.dbSchema, "sqlite version: \(sqliteVersion())")
        AppLog.log(AppLog.dbSchema, "journal_mode: \(pragma("journal_mode"))")
        AppLog.log(AppLog.dbSchema, "user_version: \(pragma("user_version"))")
        let tables = tableNames().joined(separator: ", ")
        AppLog.log(AppLog.dbSchema, "tables: \(tables)")
        AppLog.log(AppLog.dbSchema, "foods count: \(countRows(table: "foods") ?? -1)")
        if tableNames().contains("foods_fts") {
            AppLog.log(AppLog.dbSchema, "foods_fts count: \(countRows(table: "foods_fts") ?? -1)")
        }
        if let sample = querySingle(sql: "SELECT barcode, product_name, brands, quantity, countries_tags, energy_kcal_100g, proteins_100g, carbohydrates_100g, fat_100g, serving_size, image_url, last_updated_t, popularity, source FROM foods LIMIT 1;", bind: nil) {
            AppLog.log(AppLog.dbSchema, "sample row: \(sample.barcode) \(sample.name)")
        }
    }

    private func sqliteVersion() -> String {
        let sql = "SELECT sqlite_version();"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return "unknown" }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
            return String(cString: c)
        }
        return "unknown"
    }

    private func pragma(_ name: String) -> String {
        let sql = "PRAGMA \(name);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return "unknown" }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
            return String(cString: c)
        }
        return "unknown"
    }
#endif
}
