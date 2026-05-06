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
            .background(Color(.systemGroupedBackground))

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
                            TransactionListRow(
                                transaction: transaction,
                                isArchived: archivedIds.contains(transaction.id),
                                isPinned: pinnedIds.contains(transaction.id),
                                isCompleted: completedIds.contains(transaction.id),
                                isMarked: markedIds.contains(transaction.id),
                                onArchive: { archivedIds.insert(transaction.id) },
                                onPin: { toggle(&pinnedIds, transaction.id) },
                                onComplete: { toggle(&completedIds, transaction.id) },
                                onMark: { toggle(&markedIds, transaction.id) },
                                onMore: { moreActionsTarget = transaction }
                            )
                            .environmentObject(appState)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(Color(.systemGroupedBackground))
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

    private func toggle(_ set: inout Set<UUID>, _ id: UUID) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
    }
}

private struct TransactionListRow: View {
    @EnvironmentObject private var appState: AppState
    let transaction: TransactionItem
    let isArchived: Bool
    let isPinned: Bool
    let isCompleted: Bool
    let isMarked: Bool
    let onArchive: () -> Void
    let onPin: () -> Void
    let onComplete: () -> Void
    let onMark: () -> Void
    let onMore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(transaction.type == .expense ? .orange : .green)
                .frame(width: 30, height: 30)
                .background((transaction.type == .expense ? Color.orange : Color.green).opacity(0.12))
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
                if isPinned {
                    Text("Pinned")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                if isCompleted {
                    Text("Completed")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                if isMarked {
                    Text("Marked")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if isArchived {
                    Text("Archived")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }

            Spacer()

            Text(amountText)
                .fontWeight(.bold)
                .foregroundStyle(transaction.type == .expense ? .red : .green)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                appState.deleteTransaction(id: transaction.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.gray)
            Button(action: onMore) {
                Label("More", systemImage: "ellipsis")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(action: onMark) {
                Label("Mark", systemImage: "flag")
            }
            .tint(.orange)
            Button(action: onPin) {
                Label("Pin", systemImage: "pin")
            }
            .tint(.yellow)
            Button(action: onComplete) {
                Label("Complete", systemImage: "checkmark.circle")
            }
            .tint(.green)
            Button {
                duplicateIfExpense(transaction)
            } label: {
                Label("Secondary", systemImage: "plus.rectangle.on.rectangle")
            }
            .tint(.indigo)
        }
    }

    private var iconName: String {
        let text = transaction.category.lowercased()
        if text.contains("rent") { return "house.fill" }
        if text.contains("grocer") { return "cart.fill" }
        if text.contains("transport") { return "car.fill" }
        if text.contains("eat") || text.contains("coffee") { return "fork.knife" }
        if text.contains("pay") || text.contains("income") { return "dollarsign.circle.fill" }
        return "tag.fill"
    }

    private var amountText: String {
        let sign = transaction.type == .expense ? "-" : "+"
        let netAmount = transaction.type == .expense ? max(0, transaction.amount - transaction.savedApplied) : transaction.amount
        return "\(sign)\(netAmount.formatted(appState.currencyFormatter))"
    }

    private func duplicateIfExpense(_ transaction: TransactionItem) {
        guard transaction.type == .expense else { return }
        appState.addTransaction(
            amount: transaction.amount,
            category: transaction.category,
            note: "Duplicate: \(transaction.note)",
            type: .expense
        )
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
