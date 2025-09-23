import Foundation

protocol SearchService {
    func product(code: String) async throws -> Product
    func search(query: String, country: String?, nearbyStoreSlugs: [String]) async throws -> [ProductLite]
}
