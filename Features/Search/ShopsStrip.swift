import SwiftUI

struct ShopsStrip: View {
    let stores: [Store]
    var body: some View {
        if stores.isEmpty { EmptyView() }
        else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stores) { s in
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(s.name)
                            Text("· \(s.distanceString)").foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    }
                }.padding(.horizontal)
            }
            .padding(.vertical, 4)
        }
    }
}
