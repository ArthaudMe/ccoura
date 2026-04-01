import Foundation

enum DateHelpers {
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFractionFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func dayKey(from date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    static func date(from dayKey: String) -> Date? {
        dayKeyFormatter.date(from: dayKey)
    }

    static func today() -> String {
        dayKey(from: .now)
    }

    static func daysAgo(_ days: Int, from date: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: date) ?? date
    }

    static func dayKeyDaysAgo(_ days: Int) -> String {
        dayKey(from: daysAgo(days))
    }

    static func parseISO8601(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
            ?? iso8601NoFractionFormatter.date(from: string)
    }

    static func iso8601String(from date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    static func daysBetween(from: String, to: String) -> Int {
        guard let fromDate = date(from: from),
              let toDate = date(from: to) else { return 0 }
        return Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day ?? 0
    }

    static func allDayKeys(from startKey: String, to endKey: String) -> [String] {
        guard let start = date(from: startKey),
              let end = date(from: endKey) else { return [] }
        var keys: [String] = []
        var current = start
        while current <= end {
            keys.append(dayKey(from: current))
            current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? end.addingTimeInterval(1)
        }
        return keys
    }

    static func relativeDescription(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    static func dayOfWeek(for dayKey: String) -> String? {
        guard let date = date(from: dayKey) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
