import Foundation
import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: TransactionFilter = .all
    @State private var searchText: String = ""
    @State private var completedIds: Set<UUID> = []
    @State private var markedIds: Set<UUID> = []
    @State private var moreActionsTarget: TransactionItem?
    private let calendar = Calendar.current

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
                summarySection

                ForEach(groupedTransactions) { group in
                    Section {
                        ForEach(group.transactions) { transaction in
                            transactionRow(for: transaction)
                                .listRowBackground(Color.clear)
                        }
                    } header: {
                        groupHeader(group)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .reservesBottomNavSpace()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Transactions")
        .searchable(text: $searchText, prompt: "Search merchant or category")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AppOverflowMenu()
            }
        }
        .confirmationDialog(
            "More Actions",
            isPresented: Binding(
                get: { moreActionsTarget != nil },
                set: { isPresented in
                    if !isPresented { moreActionsTarget = nil }
                }
            ),
            presenting: moreActionsTarget
        ) { item in
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

    @ViewBuilder
    private var summarySection: some View {
        let summary = FinanceCalculator.filterSummary(
            for: filter.calculatorMode,
            transactions: filteredTransactions
        )
        Section("Summary") {
            switch filter {
            case .all:
                summaryRow(label: "Income", value: summary.totalIncome, color: .green, sign: "+")
                summaryRow(label: "Expenses", value: summary.totalExpenses, color: .red, sign: "-")
                summaryRow(
                    label: summary.netLabel,
                    value: summary.net,
                    color: summary.net >= 0 ? .green : .red,
                    sign: summary.net >= 0 ? "+" : "-"
                )
            case .expenses:
                summaryRow(label: "Expenses", value: summary.totalExpenses, color: .red, sign: "-")
                metaRow(label: "Number of expenses", value: "\(summary.expenseCount)")
                if summary.expenseCount > 0 {
                    summaryRow(
                        label: "Average expense",
                        value: summary.averageExpenses,
                        color: .secondary,
                        sign: "-"
                    )
                }
            case .income:
                summaryRow(label: "Income", value: summary.totalIncome, color: .green, sign: "+")
                metaRow(label: "Expenses", value: "$0.00")
                metaRow(label: "Number of income entries", value: "\(summary.incomeCount)")
                if summary.incomeCount > 0 {
                    summaryRow(
                        label: "Average income",
                        value: summary.averageIncome,
                        color: .secondary,
                        sign: "+"
                    )
                }
            }
        }
    }

    private func summaryRow(label: String, value: Double, color: Color, sign: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(sign)\(abs(value).formatted(appState.currencyFormatter))")
                .foregroundStyle(color)
                .fontWeight(.semibold)
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func groupHeader(_ group: FinanceCalculator.DailyTransactionGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateHeader(for: group.date))
                .font(.headline)
            Text(groupSummaryText(group))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func groupSummaryText(_ group: FinanceCalculator.DailyTransactionGroup) -> String {
        let expenses = "Expenses -\(group.expenses.formatted(appState.currencyFormatter))"
        let income = "Income +\(group.income.formatted(appState.currencyFormatter))"
        let netSign = group.net >= 0 ? "+" : "-"
        let net = "Net \(netSign)\(abs(group.net).formatted(appState.currencyFormatter))"
        return "\(expenses) • \(income) • \(net)"
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

        let sortedPinnedFirst = filteredByType.sorted { lhs, rhs in
            let leftPinned = appState.pinnedTransactionIds.contains(lhs.id)
            let rightPinned = appState.pinnedTransactionIds.contains(rhs.id)
            if leftPinned != rightPinned {
                return leftPinned && !rightPinned
            }
            return lhs.createdAt > rhs.createdAt
        }

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sortedPinnedFirst
        }
        return sortedPinnedFirst.filter {
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.note.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedTransactions: [FinanceCalculator.DailyTransactionGroup] {
        FinanceCalculator.groupTransactionsByDay(filteredTransactions, calendar: calendar)
    }

    private func toggle(_ set: inout Set<UUID>, _ id: UUID) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
    }

    private func dateHeader(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let currentYear = calendar.component(.year, from: Date())
        let dateYear = calendar.component(.year, from: date)

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = dateYear == currentYear ? "EEEE, MMM d" : "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func transactionRow(for transaction: TransactionItem) -> some View {
        let id = transaction.id
        TransactionListRow(
            transaction: transaction,
            isPinned: appState.pinnedTransactionIds.contains(id),
            isCompleted: completedIds.contains(id),
            isMarked: markedIds.contains(id),
            onPin: { togglePinned(id) },
            onComplete: { toggleCompleted(id) },
            onMark: { toggleMarked(id) },
            onMore: { moreActionsTarget = transaction },
            onDelete: {
                if let removed = appState.removeTransaction(id: id) {
                    appState.presentRemovedTransactionUndo(removed)
                }
            }
        )
        .environmentObject(appState)
    }

    private func togglePinned(_ id: UUID) {
        toggle(&appState.pinnedTransactionIds, id)
    }

    private func toggleCompleted(_ id: UUID) {
        toggle(&completedIds, id)
    }

    private func toggleMarked(_ id: UUID) {
        toggle(&markedIds, id)
    }
}

private struct TransactionListRow: View {
    @EnvironmentObject private var appState: AppState
    let transaction: TransactionItem
    let isPinned: Bool
    let isCompleted: Bool
    let isMarked: Bool
    let onPin: () -> Void
    let onComplete: () -> Void
    let onMark: () -> Void
    let onMore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            leadingIcon
            rowDetails
            Spacer()

            Text(amountText)
                .fontWeight(.bold)
                .foregroundStyle(transaction.type == .expense ? .red : .green)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
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

    private var leadingIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(transaction.type == .expense ? .orange : .green)
            .frame(width: 30, height: 30)
            .background((transaction.type == .expense ? Color.orange : Color.green).opacity(0.12))
            .clipShape(Circle())
    }

    private var rowDetails: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(transaction.name)
                .fontWeight(.semibold)
            Text(transaction.category)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(transaction.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if transaction.type == .expense && transaction.savedApplied > 0 {
                Text("Used \(transaction.savedApplied.formatted(appState.currencyFormatter)) from saved")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            statusBadges
        }
    }

    @ViewBuilder
    private var statusBadges: some View {
        // Render only when the user explicitly applied the status to this transaction.
        if isPinned || isCompleted || isMarked {
            HStack(spacing: 6) {
                if isPinned {
                    statusBadge(icon: "pin.fill", text: "Pinned", color: .yellow)
                }
                if isCompleted {
                    statusBadge(icon: "checkmark.circle.fill", text: "Completed", color: .green)
                }
                if isMarked {
                    statusBadge(icon: "flag.fill", text: "Marked", color: .orange)
                }
            }
            .padding(.top, 2)
        }
    }

    private func statusBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12), in: Capsule())
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
        let netAmount = transaction.type == .expense ? BudgetSpendCalculator.netExpenseAmount(transaction) : transaction.amount
        return "\(sign)\(netAmount.formatted(appState.currencyFormatter))"
    }

    private func duplicateIfExpense(_ transaction: TransactionItem) {
        guard transaction.type == .expense else { return }
        appState.addTransaction(
            amount: transaction.amount,
            name: transaction.name,
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

    var calculatorMode: FinanceCalculator.TransactionFilterMode {
        switch self {
        case .all: return .all
        case .expenses: return .expenses
        case .income: return .income
        }
    }
}

#Preview {
    NavigationStack {
        TransactionsView()
            .environmentObject(AppState())
    }
}
