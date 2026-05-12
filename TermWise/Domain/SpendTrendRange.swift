import Foundation

/// Calendar window presets for the dashboard Spending Trend chart.
enum SpendTrendRange: String, CaseIterable {
    /// Last 7 calendar days ending today (same span as ``oneWeek``).
    case sevenDays
    /// Same window as ``sevenDays`` — separate picker label (`1W`).
    case oneWeek
    case thirtyDays
    case currentMonth

    /// Segments shown in the Variable Spending Trend picker (Total trend uses ``currentMonth`` only).
    static var variablePickerCases: [SpendTrendRange] {
        [.sevenDays, .oneWeek, .thirtyDays, .currentMonth]
    }

    /// Horizontal span (`7`, `30`, or full calendar month length).
    func selectedDays(daysInCalendarMonth: Int) -> Int {
        switch self {
        case .sevenDays, .oneWeek: return 7
        case .thirtyDays: return 30
        case .currentMonth:
            return max(1, daysInCalendarMonth)
        }
    }

    /// Trailing windows that cover only history through today (no future chart slots).
    var isTrailingShortRange: Bool {
        switch self {
        case .sevenDays, .oneWeek, .thirtyDays: return true
        case .currentMonth: return false
        }
    }
}
