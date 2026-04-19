import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "CalrAI"

    static let dbBundle = Logger(subsystem: subsystem, category: "db.bundle")
    static let dbCopy = Logger(subsystem: subsystem, category: "db.copy")
    static let dbOpen = Logger(subsystem: subsystem, category: "db.open")
    static let dbSchema = Logger(subsystem: subsystem, category: "db.schema")
    static let dbQuery = Logger(subsystem: subsystem, category: "db.query")
    static let dbFTS = Logger(subsystem: subsystem, category: "db.fts")
    static let repoSearch = Logger(subsystem: subsystem, category: "repo.search")
    static let repoBarcode = Logger(subsystem: subsystem, category: "repo.barcode")
    static let uiSearch = Logger(subsystem: subsystem, category: "ui.search")
    static let uiDiary = Logger(subsystem: subsystem, category: "ui.diary")

    static var debugDBLogsEnabled: Bool {
#if DEBUG
        if UserDefaults.standard.object(forKey: "DEBUG_DB_LOGS") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "DEBUG_DB_LOGS")
#else
        return false
#endif
    }

    static func log(_ logger: Logger, _ message: String) {
        guard debugDBLogsEnabled else { return }
        logger.info("\(message, privacy: .public)")
    }

    static func warn(_ logger: Logger, _ message: String) {
        guard debugDBLogsEnabled else { return }
        logger.warning("\(message, privacy: .public)")
    }
}
