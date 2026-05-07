import SwiftUI

struct BudgetPlanView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var focusedCategoryId: UUID?
    @State private var editingCategoryIds: Set<UUID> = []
    @State private var showingAddTransactionSheet = false
    @State private var newCategoryName: String = ""
    @State private var newCategoryAmount: String = ""
    @State private var newCategoryBudgetType: BudgetType = .variable
    @State private var newCategoryFrequency: PaymentFrequency = .none
    @State private var newCategoryDueDay: Int = 1
    @State private var newCategoryDueWeekday: Int = 2
    @State private var newCategoryDueDate: Date = Date()
    @State private var fullyPaidToast: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard
                tuitionSavingsCard

                sectionHeader("Recurring Bills / Fixed Expenses")
                ForEach(fixedItemIndices, id: \.self) { index in
                    budgetCategoryCard(item: $appState.budgetItems[index])
                }

                sectionHeader("Variable Spending")
                ForEach(variableItemIndices, id: \.self) { index in
                    budgetCategoryCard(item: $appState.budgetItems[index])
                }

                addCategoryCard
            }
            .padding()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let toast = fullyPaidToast {
                Text(toast)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.14))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.green.opacity(0.35))
                            .frame(height: 1)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: fullyPaidToast)
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Budget Plan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 10) {
                    Menu {
                        Button("Add Expense", systemImage: "minus.circle") {
                            appState.draftTransactionType = .expense
                            showingAddTransactionSheet = true
                        }
                        Button("Add Income", systemImage: "plus.circle") {
                            appState.draftTransactionType = .income
                            showingAddTransactionSheet = true
                        }
                        Button("Add Category", systemImage: "square.grid.2x2.badge.plus") {
                            focusedCategoryId = nil
                        }
                        Button("Add Recurring Bill", systemImage: "calendar.badge.plus") {
                            newCategoryBudgetType = .fixed
                            newCategoryFrequency = .monthly
                        }
                    } label: {
                        Image(systemName: "plus")
                    }

                    AppOverflowMenu()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedCategoryId = nil }
            }
        }
        .sheet(isPresented: $showingAddTransactionSheet) {
            NavigationStack {
                AddTransactionView(defaultType: appState.draftTransactionType) {
                    showingAddTransactionSheet = false
                }
                .environmentObject(appState)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Monthly Snapshot")
                .font(.headline)
            metricRow("Planned Total", appState.totalPlannedSpend)
            metricRow("Actual Spend (Budget Counted)", appState.totalBudgetCountedSpend)
            if appState.totalSavedApplied > 0 {
                metricRow("Used from Saved", appState.totalSavedApplied)
                metricRow("Gross Spent", appState.totalActualSpend)
            }
            metricRow("Delta", appState.totalPlannedSpend - appState.totalBudgetCountedSpend, emphasize: true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var tuitionSavingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tuition/Savings Goal")
                .font(.headline)
            Text("Goal: \(appState.tuitionGoal.formatted(appState.currencyFormatter))")
                .font(.subheadline)
            Text("Projected monthly savings: \(appState.projectedSavingsThisMonth.formatted(appState.currencyFormatter))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func markFixedBillFullyPaidIfNeeded(billId: UUID, billCategory: String) {
        guard let bill = appState.budgetItems.first(where: { $0.id == billId && $0.budgetType == .fixed }) else { return }
        let preActual = appState.actualPaidAmount(for: bill)
        let remaining = bill.planned - preActual
        guard remaining > 0 else { return }
        guard let txn = appState.markFixedBillRemainingPaid(billId: billId) else { return }
        appState.presentMarkAsPaidUndo(
            billId: billId,
            transactionId: txn.id,
            addedAmount: remaining,
            billCategoryName: billCategory
        )
        fullyPaidToast = "Fully paid \(billCategory)"
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { fullyPaidToast = nil }
        }
    }

    private func budgetCategoryCard(item: Binding<BudgetItem>) -> some View {
        let id = item.wrappedValue.id
        let actual = item.wrappedValue.budgetType == .fixed
            ? appState.actualPaidAmount(for: item.wrappedValue)
            : appState.actualAmount(for: item.wrappedValue.category)
        let isEditing = editingCategoryIds.contains(id)
        let dueDateText = getDueDateText(item.wrappedValue)
        let isFixed = item.wrappedValue.budgetType == .fixed
        let remaining = max(0, item.wrappedValue.planned - actual)
        let fixedStatus = appState.fixedBillStatus(for: item.wrappedValue)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if isEditing {
                    TextField("Category", text: item.category)
                        .font(.headline)
                } else {
                    Text(item.wrappedValue.category)
                        .font(.headline)
                }
                Spacer()
                if isFixed {
                    Text(fixedStatusText(fixedStatus))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(fixedStatusColor(fixedStatus).opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Text(actual > item.wrappedValue.planned ? "Over Budget" : "On Track")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((actual > item.wrappedValue.planned ? Color.red : Color.green).opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            ProgressView(
                value: min(actual, item.wrappedValue.planned),
                total: max(1, item.wrappedValue.planned)
            )
                .tint(
                    actual > item.wrappedValue.planned
                        ? .red
                        : (isFixed && actual >= item.wrappedValue.planned ? .green : .blue)
                )

            HStack {
                Text("Planned")
                Spacer()
                if isEditing {
                    TextField("0", value: item.planned, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($focusedCategoryId, equals: item.wrappedValue.id)
                } else {
                    Text(item.wrappedValue.planned.formatted(appState.currencyFormatter))
                        .foregroundStyle(.secondary)
                }
            }

            if isFixed, let dueDateText {
                HStack {
                    Text("Due date")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isEditing {
                        VStack(alignment: .trailing, spacing: 8) {
                            Picker("Frequency", selection: Binding(
                                get: { item.wrappedValue.frequency },
                                set: { item.wrappedValue.frequency = $0 }
                            )) {
                                ForEach(PaymentFrequency.allCases.filter { $0 != .none }) { frequency in
                                    Text(frequency.label).tag(frequency)
                                }
                            }
                            .pickerStyle(.menu)

                            if item.wrappedValue.frequency == .monthly {
                                Stepper("Due day: \(item.wrappedValue.dueDay ?? 1)", value: Binding(
                                    get: { item.wrappedValue.dueDay ?? 1 },
                                    set: { item.wrappedValue.dueDay = $0 }
                                ), in: 1...31)
                            }
                            if item.wrappedValue.frequency == .weekly || item.wrappedValue.frequency == .biweekly {
                                Picker("Weekday", selection: Binding(
                                    get: { item.wrappedValue.dueWeekday ?? 2 },
                                    set: { item.wrappedValue.dueWeekday = $0 }
                                )) {
                                    ForEach(2...8, id: \.self) { weekday in
                                        let normalized = weekday == 8 ? 1 : weekday
                                        Text(weekdayName(normalized)).tag(normalized)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            if item.wrappedValue.frequency == .oneTime {
                                DatePicker(
                                    "One-time date",
                                    selection: Binding(
                                        get: { item.wrappedValue.dueDate ?? Date() },
                                        set: { item.wrappedValue.dueDate = $0 }
                                    ),
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                            }
                            if actual < item.wrappedValue.planned {
                                Button("Mark as Paid") {
                                    markFixedBillFullyPaidIfNeeded(
                                        billId: id,
                                        billCategory: item.wrappedValue.category
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .font(.caption)
                            }
                        }
                    }
                    Text(dueDateText)
                        .font(.subheadline)
                }
            }

            HStack {
                Text("Actual")
                Spacer()
                Text(actual.formatted(appState.currencyFormatter))
                    .foregroundStyle(actual > item.wrappedValue.planned ? .red : .secondary)
            }

            if isFixed {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(fixedStatusText(fixedStatus))
                        .foregroundStyle(fixedStatusColor(fixedStatus))
                }
                HStack {
                    Spacer()
                    if actual >= item.wrappedValue.planned {
                        Label("Paid", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    } else {
                        Button("Mark as Paid") {
                            markFixedBillFullyPaidIfNeeded(
                                billId: id,
                                billCategory: item.wrappedValue.category
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                Text("\(BudgetProgressMetrics.percentUsed(actual: actual, planned: item.wrappedValue.planned))% used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text(remaining.formatted(appState.currencyFormatter))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Delete This Month", role: .destructive) {
                    appState.hideBudgetItemForCurrentMonth(id)
                    editingCategoryIds.remove(id)
                }
                .buttonStyle(.bordered)
                Spacer()
                Button(isEditing ? "Done" : "Edit") {
                    toggleEditing(for: id)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func metricRow(_ label: String, _ value: Double, emphasize: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.formatted(appState.currencyFormatter))
                .foregroundStyle(emphasize ? (value < 0 ? .red : .green) : .secondary)
                .fontWeight(emphasize ? .semibold : .regular)
        }
    }

    private var fixedItemIndices: [Int] {
        appState.budgetItems.indices.filter {
            appState.budgetItems[$0].budgetType == .fixed &&
            !appState.isBudgetItemHiddenForCurrentMonth(appState.budgetItems[$0].id)
        }
    }

    private var variableItemIndices: [Int] {
        appState.budgetItems.indices.filter {
            appState.budgetItems[$0].budgetType == .variable &&
            !appState.isBudgetItemHiddenForCurrentMonth(appState.budgetItems[$0].id)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.top, 4)
    }

    private var addCategoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Category / Recurring Bill")
                .font(.headline)

            TextField("Category name", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)

            TextField("Monthly amount", text: $newCategoryAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            Picker("Budget type", selection: $newCategoryBudgetType) {
                ForEach(BudgetType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.menu)

            if newCategoryBudgetType == .fixed {
                Picker("Payment frequency", selection: $newCategoryFrequency) {
                    ForEach(PaymentFrequency.allCases.filter { $0 != .none }) { frequency in
                        Text(frequency.label).tag(frequency)
                    }
                }
                .pickerStyle(.menu)

                if newCategoryFrequency == .monthly {
                    Stepper("Due day: \(newCategoryDueDay)", value: $newCategoryDueDay, in: 1...31)
                        .font(.subheadline)
                }
                if newCategoryFrequency == .weekly || newCategoryFrequency == .biweekly {
                    Picker("Due weekday", selection: $newCategoryDueWeekday) {
                        ForEach(2...8, id: \.self) { weekday in
                            let normalized = weekday == 8 ? 1 : weekday
                            Text(weekdayName(normalized)).tag(normalized)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if newCategoryFrequency == .oneTime {
                    DatePicker("Due date", selection: $newCategoryDueDate, displayedComponents: .date)
                }
            }

            Button("Add Category") {
                appState.addBudgetCategory(
                    name: newCategoryName,
                    planned: Double(newCategoryAmount) ?? 0,
                    budgetType: newCategoryBudgetType,
                    frequency: newCategoryBudgetType == .fixed ? newCategoryFrequency : .none,
                    dueDay: (newCategoryBudgetType == .fixed && newCategoryFrequency == .monthly) ? newCategoryDueDay : nil,
                    dueWeekday: (newCategoryBudgetType == .fixed && (newCategoryFrequency == .weekly || newCategoryFrequency == .biweekly)) ? newCategoryDueWeekday : nil,
                    dueDate: (newCategoryBudgetType == .fixed && newCategoryFrequency == .oneTime) ? newCategoryDueDate : nil,
                    isPaid: false
                )
                newCategoryName = ""
                newCategoryAmount = ""
                newCategoryBudgetType = .variable
                newCategoryFrequency = .none
                newCategoryDueDay = 1
                newCategoryDueWeekday = 2
                newCategoryDueDate = Date()
            }
            .buttonStyle(.borderedProminent)
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Double(newCategoryAmount) ?? -1) < 0)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func toggleEditing(for id: UUID) {
        if editingCategoryIds.contains(id) {
            editingCategoryIds.remove(id)
            focusedCategoryId = nil
        } else {
            editingCategoryIds.insert(id)
            focusedCategoryId = id
        }
    }

    private func getDueDateText(_ item: BudgetItem) -> String? {
        if item.budgetType != .fixed || item.frequency == .none { return nil }
        switch item.frequency {
        case .monthly:
            guard let dueDay = item.dueDay else { return nil }
            return "Monthly • Day \(dueDay)"
        case .weekly:
            guard let dueWeekday = item.dueWeekday else { return nil }
            return "Weekly • \(weekdayName(dueWeekday))"
        case .biweekly:
            guard let dueWeekday = item.dueWeekday else { return nil }
            return "Biweekly • \(weekdayName(dueWeekday))"
        case .oneTime:
            guard let dueDate = item.dueDate else { return nil }
            return "One-time • \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        case .none:
            return nil
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index]
    }

    private func fixedStatusText(_ status: FixedBillStatus) -> String {
        switch status {
        case .paid: return "Paid"
        case .upcoming: return "Upcoming"
        case .overdue: return "Overdue"
        }
    }

    private func fixedStatusColor(_ status: FixedBillStatus) -> Color {
        switch status {
        case .paid: return .green
        case .upcoming: return .orange
        case .overdue: return .red
        }
    }
}

#Preview {
    NavigationStack {
        BudgetPlanView()
            .environmentObject(AppState())
    }
}
