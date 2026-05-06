import Foundation
import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: TransactionFilter = .all
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $filter) {
                ForEach(TransactionFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            List {
                Section("Summary") {
                    HStack {
                        Text("Income")
                        Spacer()
                        Text(totalIncome.formatted(appState.currencyFormatter))
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Expenses")
                        Spacer()
                        Text(totalExpenses.formatted(appState.currencyFormatter))
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Net")
                        Spacer()
                        Text((totalIncome - totalExpenses).formatted(appState.currencyFormatter))
                            .foregroundStyle((totalIncome - totalExpenses) >= 0 ? .green : .red)
                            .fontWeight(.semibold)
                    }
                }

                ForEach(groupedDates, id: \.self) { day in
                    Section(day.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(groupedTransactions[day] ?? []) { transaction in
                            HStack(spacing: 12) {
                                Image(systemName: iconName(for: transaction.category))
                                    .foregroundStyle(.blue)
                                    .frame(width: 30, height: 30)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(transaction.category)
                                        .fontWeight(.semibold)
                                    Text(transaction.note.isEmpty ? "No note" : transaction.note)
                                        .font(.subheadline)
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
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Transactions")
        .searchable(text: $searchText, prompt: "Search merchant or category")
    }

    private var filteredTransactions: [TransactionItem] {
        let filteredByType: [TransactionItem]
        switch filter {
        case .all:
            filteredByType = appState.transactions
        case .expenses:
            filteredByType = appState.transactions.filter { $0.type == .expense }
        case .income:
            filteredByType = appState.transactions.filter { $0.type == .income }
        }

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return filteredByType
        }
        return filteredByType.filter {
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.note.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedTransactions: [Date: [TransactionItem]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
    }

    private var groupedDates: [Date] {
        groupedTransactions.keys.sorted(by: >)
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
        return "\(sign)\(transaction.amount.formatted(appState.currencyFormatter))"
    }

    private func iconName(for category: String) -> String {
        let text = category.lowercased()
        if text.contains("rent") { return "house.fill" }
        if text.contains("grocer") { return "cart.fill" }
        if text.contains("transport") { return "car.fill" }
        if text.contains("eat") || text.contains("coffee") { return "fork.knife" }
        if text.contains("pay") || text.contains("income") { return "dollarsign.circle.fill" }
        return "tag.fill"
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
