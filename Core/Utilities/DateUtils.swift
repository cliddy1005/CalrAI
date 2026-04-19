import Foundation

enum DateUtils {
    private static let diaryTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEE, d MMM"
        return formatter
    }()

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func startOfWeekMonday(for date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        return cal.startOfDay(for: start)
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func isToday(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }

    static func formattedDiaryTitle(_ date: Date, calendar: Calendar = .current) -> String {
        guard !isToday(date, calendar: calendar) else { return "Today" }
        return diaryTitleFormatter.string(from: date)
    }
}
