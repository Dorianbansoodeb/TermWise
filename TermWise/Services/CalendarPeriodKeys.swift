import Foundation

/// Stable string keys for month/week maps (matches cache + future API map keys).
enum CalendarPeriodKeys {

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        return "\(year)-\(month)"
    }

    static func monthKey(forMonthLabel monthLabel: String, calendar: Calendar = .current, referenceNow: Date = Date()) -> String {
        let symbols = calendar.shortMonthSymbols
        if let monthIndex = symbols.firstIndex(where: { $0.localizedCaseInsensitiveCompare(monthLabel) == .orderedSame }) {
            let year = calendar.component(.year, from: referenceNow)
            return "\(year)-\(monthIndex + 1)"
        }
        return monthKey(for: referenceNow, calendar: calendar)
    }

    static func weekKey(calendar: Calendar = .current, now: Date = Date()) -> String {
        let week = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        return "\(year)-W\(week)"
    }
}
