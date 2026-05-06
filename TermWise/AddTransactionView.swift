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
    @State private var pendingAmount: Double = 0
    @State private var pendingCategory: String = ""
    @State private var showIrregularPrompt = false
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Add Transaction")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                }

                Picker("Type", selection: $type) {
                    ForEach(TransactionType.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let options = type == .expense ? expenseCategoryOptions : incomeCategoryOptions
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                category = option
                            } label: {
                                Text(option)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(category == option ? Color.blue.opacity(0.2) : Color.white)
                                    .overlay(
                                        Capsule()
                                            .stroke(category == option ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if category == "Other" {
                    TextField("Custom category", text: $customCategory)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. groceries for week 1", text: $note)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button("Save Transaction") {
                let resolvedCategory = resolveCategory()
                let parsedAmount = Double(amount) ?? 0
                if type == .expense && appState.shouldPromptIrregularPurchase(amount: parsedAmount) {
                    pendingAmount = parsedAmount
                    pendingCategory = resolvedCategory
                    showIrregularPrompt = true
                } else {
                    saveTransaction(amount: parsedAmount, category: resolvedCategory, savedApplied: 0)
                }
            }
            .disabled((Double(amount) ?? 0) <= 0)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background((Double(amount) ?? 0) > 0 ? Color.blue : Color.gray.opacity(0.6))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding()
            .background(.thinMaterial)
        }
        .onAppear {
            type = defaultType
            category = type == .expense ? (expenseCategoryOptions.first ?? "Other") : (incomeCategoryOptions.first ?? "Income")
            isAmountFocused = true
        }
        .alert("Irregular Purchase Detected", isPresented: $showIrregularPrompt) {
            Button("Use saved amount") {
                let apply = min(appState.availableSavedToUse, pendingAmount)
                saveTransaction(amount: pendingAmount, category: pendingCategory, savedApplied: apply)
            }
            Button("Don't use saved", role: .none) {
                saveTransaction(amount: pendingAmount, category: pendingCategory, savedApplied: 0)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This seems like an irregular/large purchase. Would you like to use your saved amount towards this transaction?")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AppOverflowMenu()
            }
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

    private func saveTransaction(amount: Double, category: String, savedApplied: Double) {
        appState.addTransaction(
            amount: amount,
            category: category,
            note: note,
            type: type,
            savedApplied: savedApplied
        )
        self.amount = ""
        self.category = ""
        self.customCategory = ""
        self.note = ""
        onSave()
    }
}

#Preview {
    NavigationStack {
        AddTransactionView(defaultType: .expense, onSave: {})
            .environmentObject(AppState())
    }
}
