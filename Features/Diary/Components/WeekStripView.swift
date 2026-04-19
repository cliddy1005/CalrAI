import SwiftUI

struct WeekStripView: View {
    typealias Day = Date
    let days: [Date]
    let selectedDate: Date
    let entryDayKeys: Set<String>
    var onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ForEach(days, id: \.self) { day in
                let label = Calendar.current.shortWeekdaySymbols[Calendar.current.component(.weekday, from: day) - 1].prefix(1)
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                let isToday = Calendar.current.isDateInToday(day)
                let isPast = day < DateUtils.startOfDay(Date())
                let hasEntry = entryDayKeys.contains(DateUtils.dayKey(day))

                Button(action: { onSelect(day) }) {
                    VStack(spacing: 6) {
                        Text(String(label))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ZStack {
                            Circle()
                                .fill(hasEntry && isPast ? Color.black : Color.clear)
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? Color.black : (isToday ? Color.blue : Color.gray.opacity(0.4)), lineWidth: 1.5)
                                )
                                .frame(width: 30, height: 30)
                            if hasEntry && isPast {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    WeekStripView(
        days: (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: DateUtils.startOfWeekMonday(for: Date())) },
        selectedDate: Date(),
        entryDayKeys: [DateUtils.dayKey(Date())],
        onSelect: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
