import SwiftUI

struct AddTransactionView: View {
    @EnvironmentObject private var appState: AppState

    let defaultType: TransactionType
    let onSave: () -> Void

    @State private var amount: String = ""
    @State private var category: String = "Other"
    @State private var customCategory: String = ""
    @State private var note: String = ""
    @State private var type: TransactionType = .expense
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        Form {
            Section("Transaction Type") {
                Picker("Type", selection: $type) {
                    ForEach(TransactionType.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Details") {
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)

                if type == .expense {
                    Picker("Category", selection: $category) {
                        ForEach(expenseCategoryOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }

                    if category == "Other" {
                        TextField("Custom category", text: $customCategory)
                    }
                } else {
                    Picker("Category", selection: $category) {
                        ForEach(incomeCategoryOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                TextField("Note", text: $note)
            }

            Section {
                Button("Save") {
                    let resolvedCategory = resolveCategory()
                    appState.addTransaction(
                        amount: Double(amount) ?? 0,
                        category: resolvedCategory,
                        note: note,
                        type: type
                    )
                    amount = ""
                    category = ""
                    customCategory = ""
                    note = ""
                    onSave()
                }
                .disabled((Double(amount) ?? 0) <= 0)
            }
        }
        .navigationTitle("Add Transaction")
        .onAppear {
            type = defaultType
            category = type == .expense ? (expenseCategoryOptions.first ?? "Other") : (incomeCategoryOptions.first ?? "Income")
            isAmountFocused = true
        }
    }

    private var expenseCategoryOptions: [String] {
        let budgetCategories = appState.budgetItems.map { $0.category }
        let base = Array(Set(budgetCategories)).sorted()
        return base + ["Other"]
    }

    private var incomeCategoryOptions: [String] {
        ["Paycheque", "Gift", "Scholarship", "Bursary", "Other"]
    }

    private func resolveCategory() -> String {
        if category == "Other" {
            let trimmed = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Other" : trimmed
        }
        return category
    }
}

#Preview {
    NavigationStack {
        AddTransactionView(defaultType: .expense, onSave: {})
            .environmentObject(AppState())
    }
}
