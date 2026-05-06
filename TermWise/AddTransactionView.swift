import SwiftUI

struct AddTransactionView: View {
    @EnvironmentObject private var appState: AppState

    let defaultType: TransactionType
    let onSave: () -> Void

    @State private var amount: String = ""
    @State private var category: String = ""
    @State private var note: String = ""
    @State private var type: TransactionType = .expense

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
                TextField("Category", text: $category)
                TextField("Note", text: $note)
            }

            Section {
                Button("Save") {
                    appState.addTransaction(
                        amount: Double(amount) ?? 0,
                        category: category.isEmpty ? "Other" : category,
                        note: note,
                        type: type
                    )
                    amount = ""
                    category = ""
                    note = ""
                    onSave()
                }
                .disabled((Double(amount) ?? 0) <= 0)
            }
        }
        .navigationTitle("Add Transaction")
        .onAppear {
            type = defaultType
        }
    }
}

#Preview {
    NavigationStack {
        AddTransactionView(defaultType: .expense, onSave: {})
            .environmentObject(AppState())
    }
}
