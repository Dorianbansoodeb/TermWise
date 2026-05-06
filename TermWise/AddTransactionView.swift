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
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if category == "Other" {
                    TextField("Custom category", text: $customCategory)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("Optional note", text: $note)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button("Save Transaction") {
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
