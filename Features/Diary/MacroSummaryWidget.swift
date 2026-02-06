import WidgetKit
import SwiftUI

struct MacroEntry: TimelineEntry {
    let date: Date
    let protein: Double
    let carbs: Double
    let fat: Double
    let goalProtein: Double
    let goalCarbs: Double
    let goalFat: Double
}

struct MacroProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacroEntry {
        MacroEntry(date: Date(), protein: 50, carbs: 120, fat: 40, goalProtein: 100, goalCarbs: 200, goalFat: 70)
    }
    func getSnapshot(in context: Context, completion: @escaping (MacroEntry) -> ()) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MacroEntry>) -> ()) {
        // For demo: static snapshot. Real apps should load from shared storage.
        let entry = placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct MacroSummaryWidgetEntryView: View {
    var entry: MacroProvider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Macros Today").font(.headline)
            HStack(spacing: 16) {
                MacroRingWidget(label: "Protein", eaten: entry.protein, target: entry.goalProtein, color: .orange)
                MacroRingWidget(label: "Carbs", eaten: entry.carbs, target: entry.goalCarbs, color: .teal)
                MacroRingWidget(label: "Fat", eaten: entry.fat, target: entry.goalFat, color: .purple)
            }
        }.padding()
    }
}

struct MacroRingWidget: View {
    let label: String
    let eaten: Double
    let target: Double
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 7)
                Circle().trim(from: 0, to: CGFloat(min(eaten / target, 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(eaten))/\(Int(target))")
                    .font(.caption2).bold()
            }.frame(width: 44, height: 44)
            Text(label).font(.caption2)
        }
    }
}

struct MacroSummaryWidget: Widget {
    let kind: String = "MacroSummaryWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MacroProvider()) { entry in
            MacroSummaryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Macros Summary")
        .description("See your daily macro progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
