import Foundation

/// Scales envelope and variable-limit lines for a shorter Spending Trend window.
///
/// With `selectedDays == daysInMonth`, all outputs match the nominal monthly envelopes.
enum SpendTrendRangeMath {
    struct Result: Equatable {
        let periodAvailableToBudget: Double
        let periodSavingsTarget: Double
        let periodSpendLimit: Double
        let periodVariableLimit: Double
    }

    /// Proportional period envelopes from full-month inputs.
    static func scaledPeriod(
        availableToBudget: Double,
        savingsTarget: Double,
        monthlyVariableLimit: Double,
        selectedDays: Int,
        daysInMonth: Int
    ) -> Result {
        guard daysInMonth > 0, selectedDays > 0 else {
            return Result(
                periodAvailableToBudget: 0,
                periodSavingsTarget: 0,
                periodSpendLimit: 0,
                periodVariableLimit: 0
            )
        }
        let ratio = Double(selectedDays) / Double(daysInMonth)
        let safeAvailable = max(0, availableToBudget)
        let safeSavings = max(0, savingsTarget)
        let periodAvailable = safeAvailable * ratio
        let periodSavings = safeSavings * ratio
        let periodSpendLimit = max(0, periodAvailable - periodSavings)
        let periodVariable = max(0, monthlyVariableLimit) * ratio
        return Result(
            periodAvailableToBudget: periodAvailable,
            periodSavingsTarget: periodSavings,
            periodSpendLimit: periodSpendLimit,
            periodVariableLimit: periodVariable
        )
    }
}
