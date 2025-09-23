import SwiftUI

struct ProductRow: View {
    let product: ProductLite
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(product.name)
                if let g = product.nutriScore {
                    Text(g.uppercased()).font(.caption2)
                        .padding(4).background(Color.gray.opacity(0.2)).clipShape(Circle())
                }
            }
            HStack(spacing: 8) {
                if let kcal = product.kcalPer100g { Text("\(Int(kcal)) kcal / 100 g") }
                if let brands = product.brands, !brands.isEmpty { Text(brands) }
                if let stores = product.stores, !stores.isEmpty { Text("at \(stores)") }
                if let scans = product.uniqueScans { Text("pop: \(scans)") }
            }
            .font(.caption).foregroundColor(.secondary)
        }
    }
}
