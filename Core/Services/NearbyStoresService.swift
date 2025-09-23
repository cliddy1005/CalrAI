import Foundation
import MapKit
import CoreLocation

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
    static let retailerNames: [String] = [
        "Tesco","Sainsbury's","Sainsburys","Asda","Morrisons","Aldi","Lidl",
        "Co-op","Coop","Waitrose","Iceland","Marks & Spencer","M&S","Ocado",
        "SuperValu","Dunnes","Supermarket","Grocery"
    ]

    static func find(around loc: CLLocation) async -> [Store] {
        var found: [Store] = []
        for q in retailerNames {
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
    do { return try await geo.reverseGeocodeLocation(loc).first?.country } catch { return nil }
}
