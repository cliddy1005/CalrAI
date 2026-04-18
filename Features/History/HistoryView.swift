import SwiftUI

/// History view showing diary entries by date with a calendar picker and stats summary.
struct HistoryView: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var entries: [DiaryEntry] = []
    @State private var weeklyStats: WeeklyStats?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    DatePicker("Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if let stats = weeklyStats {
                    WeeklyStatsBar(stats: stats)
                }

                // Entries list
                List {
                    if entries.isEmpty {
                        Text("No entries for this date")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(mealSections, id: \.0) { section in
                            Section(header: Text(section.0.capitalized)) {
                                ForEach(section.1, id: \.id) { entry in
                                    HistoryEntryRow(entry: entry)
                                }
                            }
                        }

                        Section("Daily Totals") {
                            HStack {
                                StatLabel(title: "Calories", value: "\(totalCalories)")
                                StatLabel(title: "Protein", value: "\(Int(totalProtein))g")
                                StatLabel(title: "Fat", value: "\(Int(totalFat))g")
                                StatLabel(title: "Carbs", value: "\(Int(totalCarbs))g")
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: selectedDate) {
                loadEntries()
                loadWeeklyStats()
            }
            .onAppear {
                loadEntries()
                loadWeeklyStats()
            }
        }
    }

    private var mealSections: [(String, [DiaryEntry])] {
        let grouped = Dictionary(grouping: entries, by: \.mealType)
        let order = ["breakfast", "lunch", "dinner", "snacks"]
        return order.compactMap { meal in
            guard let items = grouped[meal], !items.isEmpty else { return nil }
            return (meal, items)
        }
    }

    private var totalCalories: Int { entries.reduce(0) { $0 + $1.caloriesSnapshot } }
    private var totalProtein: Double { entries.reduce(0) { $0 + $1.proteinSnapshot } }
    private var totalFat: Double { entries.reduce(0) { $0 + $1.fatSnapshot } }
    private var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbsSnapshot } }

    private func loadEntries() {
        entries = env.localStore.fetchEntries(for: selectedDate)
    }

    private func loadWeeklyStats() {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: selectedDate))!
        let weekEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: selectedDate))!
        let weekEntries = env.localStore.fetchEntries(from: weekStart, to: weekEnd)

        let totalCals = weekEntries.reduce(0) { $0 + $1.caloriesSnapshot }
        let daysWithEntries = Set(weekEntries.map { calendar.startOfDay(for: $0.date) }).count
        let avgCals = daysWithEntries > 0 ? totalCals / daysWithEntries : 0
        let totalP = weekEntries.reduce(0.0) { $0 + $1.proteinSnapshot }
        let totalF = weekEntries.reduce(0.0) { $0 + $1.fatSnapshot }
        let totalC = weekEntries.reduce(0.0) { $0 + $1.carbsSnapshot }

        weeklyStats = WeeklyStats(
            totalCalories: totalCals, avgCalories: avgCals, daysTracked: daysWithEntries,
            totalProtein: totalP, totalFat: totalF, totalCarbs: totalC
        )
    }
}

struct WeeklyStats {
    let totalCalories: Int
    let avgCalories: Int
    let daysTracked: Int
    let totalProtein: Double
    let totalFat: Double
    let totalCarbs: Double
}

private struct WeeklyStatsBar: View {
    let stats: WeeklyStats
    var body: some View {
        VStack(spacing: 4) {
            Text("7-Day Summary")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                StatLabel(title: "Total", value: "\(stats.totalCalories) kcal")
                StatLabel(title: "Avg/day", value: "\(stats.avgCalories) kcal")
                StatLabel(title: "Days", value: "\(stats.daysTracked)")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemGray6))
    }
}

private struct StatLabel: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.bold())
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HistoryEntryRow: View {
    let entry: DiaryEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.foodName)
                if let ns = entry.nutriScore {
                    Text(ns.uppercased())
                        .font(.caption2)
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            HStack {
                if entry.isManual {
                    Text("\(entry.caloriesSnapshot) kcal (manual)")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(Int(entry.grams))g - \(entry.caloriesSnapshot) kcal")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let note = entry.note, !note.isEmpty {
                    Text(note).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }
}
