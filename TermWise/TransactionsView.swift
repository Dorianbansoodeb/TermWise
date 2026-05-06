import Foundation
import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: TransactionFilter = .all
    @State private var searchText: String = ""
    @State private var archivedIds: Set<UUID> = []
    @State private var pinnedIds: Set<UUID> = []
    @State private var completedIds: Set<UUID> = []
    @State private var markedIds: Set<UUID> = []
    @State private var moreActionsTarget: TransactionItem?

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
                    let dayTransactions = groupedTransactions[day] ?? []
                    Section(day.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(dayTransactions) { transaction in
                            transactionRow(transaction)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    appState.deleteTransaction(id: transaction.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    archivedIds.insert(transaction.id)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.gray)
                                Button {
                                    moreActionsTarget = transaction
                                } label: {
                                    Label("More", systemImage: "ellipsis")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    if markedIds.contains(transaction.id) { markedIds.remove(transaction.id) } else { markedIds.insert(transaction.id) }
                                } label: {
                                    Label("Mark", systemImage: "flag")
                                }
                                .tint(.orange)
                                Button {
                                    if pinnedIds.contains(transaction.id) { pinnedIds.remove(transaction.id) } else { pinnedIds.insert(transaction.id) }
                                } label: {
                                    Label("Pin", systemImage: "pin")
                                }
                                .tint(.yellow)
                                Button {
                                    if completedIds.contains(transaction.id) { completedIds.remove(transaction.id) } else { completedIds.insert(transaction.id) }
                                } label: {
                                    Label("Complete", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                                Button {
                                    if transaction.type == .expense {
                                        appState.addTransaction(
                                            amount: transaction.amount,
                                            category: transaction.category,
                                            note: "Duplicate: \(transaction.note)",
                                            type: .expense
                                        )
                                    }
                                } label: {
                                    Label("Secondary", systemImage: "plus.rectangle.on.rectangle")
                                }
                                .tint(.indigo)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Transactions")
        .searchable(text: $searchText, prompt: "Search merchant or category")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                AppOverflowMenu()
            }
        }
        .confirmationDialog("More Actions", item: $moreActionsTarget) { item in
            Button("Duplicate transaction") {
                appState.addTransaction(
                    amount: item.amount,
                    category: item.category,
                    note: "Duplicate: \(item.note)",
                    type: item.type,
                    savedApplied: item.savedApplied
                )
            }
            Button("Cancel", role: .cancel) {}
        }
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

        let withoutArchived = filteredByType.filter { !archivedIds.contains($0.id) }

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return withoutArchived
        }
        return withoutArchived.filter {
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.note.localizedCaseInsensitiveContains(searchText)
        }
    }

    @ViewBuilder
    private func transactionRow(_ transaction: TransactionItem) -> some View {
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
                if transaction.type == .expense && transaction.savedApplied > 0 {
                    Text("Used \(transaction.savedApplied.formatted(appState.currencyFormatter)) from saved")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if pinnedIds.contains(transaction.id) {
                    Text("Pinned")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                if completedIds.contains(transaction.id) {
                    Text("Completed")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Text(signedAmountText(for: transaction))
                .fontWeight(.bold)
                .foregroundStyle(transaction.type == .expense ? .red : .green)
        }
        .padding(.vertical, 4)
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
            .reduce(0) { $0 + max(0, $1.amount - $1.savedApplied) }
    }

    private func signedAmountText(for transaction: TransactionItem) -> String {
        let sign = transaction.type == .expense ? "-" : "+"
        let netAmount = transaction.type == .expense ? max(0, transaction.amount - transaction.savedApplied) : transaction.amount
        return "\(sign)\(netAmount.formatted(appState.currencyFormatter))"
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
