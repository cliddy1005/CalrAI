import SwiftUI

struct ProgressBarView: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * value)), height: 8)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    ProgressBarView(value: 0.6, color: .blue)
        .padding()
}
