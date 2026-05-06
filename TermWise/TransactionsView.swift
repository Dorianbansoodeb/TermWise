import Foundation
import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: TransactionFilter = .all

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(TransactionFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            Section("Summary") {
                HStack {
                    Text("Income")
                    Spacer()
                    Text(totalIncome.formatted(.currency(code: "USD")))
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Expenses")
                    Spacer()
                    Text(totalExpenses.formatted(.currency(code: "USD")))
                        .foregroundStyle(.red)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Net")
                    Spacer()
                    Text((totalIncome - totalExpenses).formatted(.currency(code: "USD")))
                        .foregroundStyle((totalIncome - totalExpenses) >= 0 ? .green : .red)
                        .fontWeight(.semibold)
                }
            }

            Section("Recent") {
                ForEach(filteredTransactions) { transaction in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(transaction.category)
                                .fontWeight(.semibold)
                            Text(transaction.note.isEmpty ? "No note" : transaction.note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(transaction.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(signedAmountText(for: transaction))
                            .fontWeight(.bold)
                            .foregroundStyle(transaction.type == .expense ? .red : .green)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Transactions")
    }

    private var filteredTransactions: [TransactionItem] {
        switch filter {
        case .all:
            return appState.transactions
        case .expenses:
            return appState.transactions.filter { $0.type == .expense }
        case .income:
            return appState.transactions.filter { $0.type == .income }
        }
    }

    private var totalIncome: Double {
        filteredTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        filteredTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private func signedAmountText(for transaction: TransactionItem) -> String {
        let sign = transaction.type == .expense ? "-" : "+"
        return "\(sign)\(transaction.amount.formatted(.currency(code: "USD")))"
    }
}

private enum TransactionFilter: String, CaseIterable, Identifiable {
    case all
    case expenses
    case income

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .expenses: return "Expenses"
        case .income: return "Income"
        }
    }
}

#Preview {
    NavigationStack {
        TransactionsView()
            .environmentObject(AppState())
    }
}
