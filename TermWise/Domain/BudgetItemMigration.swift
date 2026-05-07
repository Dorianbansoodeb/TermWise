import Foundation

/// Schema / seed migrations for `BudgetItem` lists loaded from disk or API.
/// Keep aligned with server migrations and Android `BudgetItemMigration`.
enum BudgetItemMigration {

    static func applyDefaults(_ items: [BudgetItem]) -> [BudgetItem] {
        var result: [BudgetItem] = items.map { item in
            var updated = item

            if item.category == "Rent", item.frequency == .none || item.dueDay == nil {
                updated.budgetType = .fixed
                updated.frequency = .monthly
                updated.dueDay = updated.dueDay ?? 1
            }

            // Items historically named "Tuition/Savings" are now Savings Goals.
            // We migrate the type, but keep `planned` as the monthly contribution.
            if item.category.localizedCaseInsensitiveContains("tuition") || item.category.localizedCaseInsensitiveContains("savings") {
                updated.budgetType = .savings
                updated.frequency = .monthly
                if updated.dueDay == nil { updated.dueDay = 7 }
            }

            if item.category.localizedCaseInsensitiveContains("phone"), item.frequency == .none || item.dueDay == nil {
                updated.budgetType = .fixed
                updated.frequency = .monthly
                updated.dueDay = 15
            }

            if updated.budgetType == .variable, updated.frequency != .none {
                updated.budgetType = .fixed
            }

            return updated
        }

        if !result.contains(where: { $0.category.localizedCaseInsensitiveContains("phone") }) {
            result.append(
                BudgetItem(
                    id: UUID(),
                    category: "Phone bill",
                    planned: 35,
                    budgetType: .fixed,
                    frequency: .monthly,
                    dueDay: 15,
                    dueWeekday: nil,
                    dueDate: nil,
                    isPaid: false
                )
            )
        }

        return result
    }
}
