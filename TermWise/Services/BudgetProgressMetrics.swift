import Foundation

/// UI-agnostic progress and ratio helpers (Compose / SwiftUI both consume the numbers).
enum BudgetProgressMetrics {

    static func percentUsed(actual: Double, planned: Double) -> Int {
        Int((actual / max(1, planned)) * 100)
    }

    static func percentUsedDouble(actual: Double, planned: Double) -> Double {
        (actual / max(1, planned)) * 100
    }
}
