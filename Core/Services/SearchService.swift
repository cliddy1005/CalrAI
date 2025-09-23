// Core/Services/SearchService.swift
import Foundation

/// A service that can fetch food products and search results.
protocol SearchService {
    /// Fetch a full product by barcode.
    func product(code: String) async throws -> Product

    /// Search for products by query, optionally narrowed by country and nearby stores.
    func search(query: String,
                country: String?,
                nearbyStoreSlugs: [String]) async throws -> [ProductLite]
}

