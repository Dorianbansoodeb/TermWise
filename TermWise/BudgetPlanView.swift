import SwiftUI

struct BudgetPlanView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAddTransactionSheet = false
    @State private var budgetEditor: BudgetItemEditorContext?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                budgetEnvelopeCard
                monthlySnapshotCard

                if !fixedItemIndices.isEmpty {
                    sectionHeader("Recurring Bills")
                    ForEach(fixedItemIndices, id: \.self) { index in
                        recurringBillCard(item: appState.budgetItems[index])
                    }
                }

                if !variableItemIndices.isEmpty {
                    sectionHeader("Variable Spending")
                    ForEach(variableItemIndices, id: \.self) { index in
                        variableSpendingCard(item: appState.budgetItems[index])
                    }
                }

                if !savingsItemIndices.isEmpty {
                    sectionHeader("Savings Goals")
                    ForEach(savingsItemIndices, id: \.self) { index in
                        savingsGoalCard(item: appState.budgetItems[index])
                    }
                }

                addBudgetItemButton
            }
            .padding()
        }
        .reservesBottomNavSpace()
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
                    } label: {
                        Image(systemName: "plus")
                    }
                    AppOverflowMenu()
                }
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
        .sheet(item: $budgetEditor) { context in
            BudgetItemEditorSheet(context: context)
                .environmentObject(appState)
        }
    }

    // MARK: - Cards

    private var budgetEnvelopeCard: some View {
        let unallocated = FinanceBudgetAllocation.unallocatedRow(
            availableToBudget: appState.availableToBudget,
            totalBudgeted: appState.totalBudgeted
        )
        return VStack(alignment: .leading, spacing: 10) {
            Text("Budget Envelope")
                .font(.headline)

            metricRow("Total Income", appState.totalIncome)

            VStack(alignment: .leading, spacing: 4) {
                Text("Available to Budget This Month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    "Amount",
                    value: Binding(
                        get: { appState.availableToBudget },
                        set: { appState.setAvailableToBudgetForCurrentMonth($0) }
                    ),
                    format: .number
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            }

            if appState.reserveNotBudgeted > 0 {
                metricRow("Reserve / Not Budgeted", appState.reserveNotBudgeted)
            }
            metricRow("Total Budgeted", appState.totalBudgeted)
            metricRow(
                unallocated.label,
                unallocated.value,
                emphasize: true,
                forceColor: unallocated.isOver ? .red : .green
            )

            if appState.availableToBudget > appState.totalIncome && appState.totalIncome > 0 {
                Text("You are budgeting more than your recorded income.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if unallocated.isOver {
                Text("Your budget is over your available amount by \(unallocated.value.formatted(appState.currencyFormatter)).")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if unallocated.value > 0 {
                Text("You have \(unallocated.value.formatted(appState.currencyFormatter)) left unallocated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var monthlySnapshotCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Monthly Snapshot")
                .font(.headline)
            metricRow("Total Budgeted", appState.totalBudgeted)
            metricRow("Actual Spend", appState.totalBudgetCountedSpend)
            if appState.totalSavedApplied > 0 {
                metricRow("Used from Cushion", appState.totalSavedApplied)
                metricRow("Gross Spent", appState.totalActualSpend)
            }
            metricRow(
                "Delta",
                appState.totalBudgeted - appState.totalBudgetCountedSpend,
                emphasize: true
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Recurring bill card (Item 12)

    private func recurringBillCard(item: BudgetItem) -> some View {
        let actual = appState.actualPaidAmount(for: item)
        let status = appState.fixedBillStatus(for: item)
        let isFullyPaid = actual >= item.planned
        let dueLabel = dueLabel(for: item)
        let progressTint: Color = isFullyPaid ? .green : (actual > item.planned ? .red : .blue)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.category)
                    .font(.headline)
                Spacer()
                statusBadge(status)
            }

            ProgressView(
                value: min(actual, item.planned),
                total: max(1, item.planned)
            )
            .tint(progressTint)

            HStack {
                Text("Planned")
                Spacer()
                Text(item.planned.formatted(appState.currencyFormatter))
                    .foregroundStyle(.secondary)
            }
            if let dueLabel {
                HStack {
                    Text("Due date")
                    Spacer()
                    Text(dueLabel)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Actual")
                Spacer()
                Text(actual.formatted(appState.currencyFormatter))
                    .foregroundStyle(actual > item.planned ? .red : .secondary)
            }

            HStack(spacing: 8) {
                if !isFullyPaid {
                    Button("Mark as Paid") {
                        markFixedBillFullyPaidIfNeeded(billId: item.id, billCategory: item.category)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                Button("Reset Payment", role: .destructive) {
                    appState.hideBudgetItemForCurrentMonth(item.id)
                }
                .buttonStyle(.bordered)
                Button("Edit") {
                    budgetEditor = BudgetItemEditorContext(mode: .edit(item.id), defaultType: .fixed)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Variable spending card

    private func variableSpendingCard(item: BudgetItem) -> some View {
        let actual = appState.actualAmount(for: item.category)
        let percentUsed = BudgetProgressMetrics.percentUsed(actual: actual, planned: item.planned)
        let remaining = max(0, item.planned - actual)
        let isOver = actual > item.planned
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.category)
                    .font(.headline)
                Spacer()
                Text(isOver ? "Over Budget" : "On Track")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isOver ? Color.red : Color.green).opacity(0.15))
                    .foregroundStyle(isOver ? .red : .green)
                    .clipShape(Capsule())
            }

            ProgressView(
                value: min(actual, item.planned),
                total: max(1, item.planned)
            )
            .tint(isOver ? .red : .blue)

            HStack {
                Text("Planned")
                Spacer()
                Text(item.planned.formatted(appState.currencyFormatter))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Actual")
                Spacer()
                Text(actual.formatted(appState.currencyFormatter))
                    .foregroundStyle(isOver ? .red : .secondary)
            }
            HStack {
                Text("Remaining")
                Spacer()
                Text(remaining.formatted(appState.currencyFormatter))
                    .foregroundStyle(.secondary)
            }
            Text("\(percentUsed)% used")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Reset This Month", role: .destructive) {
                    appState.hideBudgetItemForCurrentMonth(item.id)
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Edit") {
                    budgetEditor = BudgetItemEditorContext(mode: .edit(item.id), defaultType: .variable)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Savings goal card

    private func savingsGoalCard(item: BudgetItem) -> some View {
        let actual = appState.actualPaidAmount(for: item)
        let status = appState.fixedBillStatus(for: item)
        let isFullyPaid = actual >= item.planned
        let progressTint: Color = isFullyPaid ? .green : .blue
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.category)
                    .font(.headline)
                Spacer()
                statusBadge(status)
            }

            ProgressView(
                value: min(actual, item.planned),
                total: max(1, item.planned)
            )
            .tint(progressTint)

            HStack {
                Text("Monthly contribution")
                Spacer()
                Text(item.planned.formatted(appState.currencyFormatter))
                    .foregroundStyle(.secondary)
            }
            if let target = item.targetAmount, target > 0 {
                HStack {
                    Text("Goal target")
                    Spacer()
                    Text(target.formatted(appState.currencyFormatter))
                        .foregroundStyle(.secondary)
                }
            }
            if let deadline = item.deadline {
                HStack {
                    Text("Deadline")
                    Spacer()
                    Text(deadline.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Contributed this month")
                Spacer()
                Text(actual.formatted(appState.currencyFormatter))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if !isFullyPaid {
                    Button("Mark as Paid") {
                        markFixedBillFullyPaidIfNeeded(billId: item.id, billCategory: item.category)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                Button("Reset Payment", role: .destructive) {
                    appState.hideBudgetItemForCurrentMonth(item.id)
                }
                .buttonStyle(.bordered)
                Button("Edit") {
                    budgetEditor = BudgetItemEditorContext(mode: .edit(item.id), defaultType: .savings)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Add button + sections

    private var addBudgetItemButton: some View {
        Button {
            budgetEditor = BudgetItemEditorContext(mode: .add, defaultType: .variable)
        } label: {
            Label("Add Budget Item", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

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

    private var savingsItemIndices: [Int] {
        appState.budgetItems.indices.filter {
            appState.budgetItems[$0].budgetType == .savings &&
            !appState.isBudgetItemHiddenForCurrentMonth(appState.budgetItems[$0].id)
        }
    }

    private func metricRow(_ label: String, _ value: Double, emphasize: Bool = false, forceColor: Color? = nil) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.formatted(appState.currencyFormatter))
                .foregroundStyle(forceColor ?? (emphasize ? (value < 0 ? .red : .green) : .secondary))
                .fontWeight(emphasize ? .semibold : .regular)
        }
    }

    private func dueLabel(for item: BudgetItem) -> String? {
        guard let label = FixedBillSchedule.dueDayLabel(for: item) else { return nil }
        switch item.frequency {
        case .monthly: return "Monthly • \(label)"
        case .weekly: return "Weekly • \(label)"
        case .biweekly: return "Biweekly • \(label)"
        case .oneTime: return "One-time • \(label)"
        case .none: return nil
        }
    }

    private func statusBadge(_ status: FixedBillStatus) -> some View {
        let text: String
        let color: Color
        switch status {
        case .paid: text = "Paid"; color = .green
        case .upcoming: text = "Upcoming"; color = .orange
        case .overdue: text = "Overdue"; color = .red
        }
        return Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func markFixedBillFullyPaidIfNeeded(billId: UUID, billCategory: String) {
        guard let bill = appState.budgetItems.first(where: { $0.id == billId }),
              bill.budgetType == .fixed || bill.budgetType == .savings
        else { return }
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
    }
}

// MARK: - Add / edit sheet

struct BudgetItemEditorContext: Identifiable {
    enum Mode: Equatable {
        case add
        case edit(UUID)
    }

    let id = UUID()
    let mode: Mode
    let defaultType: BudgetType

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
}

private struct BudgetItemEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let context: BudgetItemEditorContext

    @State private var type: BudgetType = .variable
    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var frequency: PaymentFrequency = .monthly
    @State private var dueDay: Int = 1
    @State private var dueWeekday: Int = 2
    @State private var dueDate: Date = Date()
    @State private var targetAmountText: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadlineDate: Date = Date()
    @State private var didLoadInitialValues = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $type) {
                        Text("Variable Spending").tag(BudgetType.variable)
                        Text("Recurring Bill").tag(BudgetType.fixed)
                        Text("Savings Goal").tag(BudgetType.savings)
                    }
                    .pickerStyle(.segmented)
                }

                Section(nameSectionTitle) {
                    TextField(namePlaceholder, text: $name)
                        .textInputAutocapitalization(.words)
                    TextField(amountFieldLabel, text: $amountText)
                        .keyboardType(.decimalPad)
                }

                if type == .fixed || type == .savings {
                    Section("Schedule") {
                        Picker("Frequency", selection: $frequency) {
                            ForEach(PaymentFrequency.allCases.filter { $0 != .none }) { freq in
                                Text(freq.label).tag(freq)
                            }
                        }
                        if frequency == .monthly {
                            Stepper("Due day: \(dueDay)", value: $dueDay, in: 1...31)
                        }
                        if frequency == .weekly || frequency == .biweekly {
                            Picker("Weekday", selection: $dueWeekday) {
                                ForEach(1...7, id: \.self) { weekday in
                                    Text(weekdayName(weekday)).tag(weekday)
                                }
                            }
                        }
                        if frequency == .oneTime {
                            DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                        }
                    }
                }

                if type == .savings {
                    Section("Goal") {
                        TextField("Target amount", text: $targetAmountText)
                            .keyboardType(.decimalPad)
                        Toggle("Set deadline", isOn: $hasDeadline.animation())
                        if hasDeadline {
                            DatePicker("Deadline", selection: $deadlineDate, displayedComponents: .date)
                        }
                    }
                }

                if context.isEditing {
                    Section {
                        Button(resetButtonTitle, role: .destructive) {
                            if case .edit(let id) = context.mode {
                                appState.hideBudgetItemForCurrentMonth(id)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(context.isEditing ? "Edit Budget Item" : "Add Budget Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { loadInitialValuesIfNeeded() }
        }
    }

    private var nameSectionTitle: String {
        switch type {
        case .variable: return "Category"
        case .fixed: return "Bill"
        case .savings: return "Goal"
        }
    }

    private var namePlaceholder: String {
        switch type {
        case .variable: return "e.g. Groceries, Eating Out"
        case .fixed: return "e.g. Rent, Phone bill"
        case .savings: return "e.g. Tuition Savings, Emergency Fund"
        }
    }

    private var amountFieldLabel: String {
        switch type {
        case .variable: return "Monthly limit"
        case .fixed: return "Monthly amount"
        case .savings: return "Monthly contribution"
        }
    }

    private var resetButtonTitle: String {
        switch type {
        case .variable: return "Reset This Month"
        case .fixed, .savings: return "Reset Payment"
        }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let amount = Double(amountText), amount >= 0 else { return false }
        return true
    }

    private func loadInitialValuesIfNeeded() {
        guard !didLoadInitialValues else { return }
        didLoadInitialValues = true

        switch context.mode {
        case .add:
            type = context.defaultType
            frequency = context.defaultType == .variable ? .none : .monthly
        case .edit(let id):
            guard let item = appState.budgetItems.first(where: { $0.id == id }) else { return }
            type = item.budgetType
            name = item.category
            amountText = String(format: "%g", item.planned)
            frequency = item.frequency == .none ? .monthly : item.frequency
            dueDay = item.dueDay ?? 1
            dueWeekday = item.dueWeekday ?? 2
            dueDate = item.dueDate ?? Date()
            if let target = item.targetAmount {
                targetAmountText = String(format: "%g", target)
            }
            if let deadline = item.deadline {
                hasDeadline = true
                deadlineDate = deadline
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let planned = Double(amountText) ?? 0
        let savingsTarget = Double(targetAmountText)

        let resolvedFrequency: PaymentFrequency = type == .variable ? .none : frequency
        let resolvedDueDay = (type != .variable && resolvedFrequency == .monthly) ? dueDay : nil
        let resolvedDueWeekday = (type != .variable && (resolvedFrequency == .weekly || resolvedFrequency == .biweekly)) ? dueWeekday : nil
        let resolvedDueDate = (type != .variable && resolvedFrequency == .oneTime) ? dueDate : nil
        let resolvedDeadline: Date? = (type == .savings && hasDeadline) ? deadlineDate : nil
        let resolvedTarget: Double? = type == .savings ? savingsTarget : nil

        switch context.mode {
        case .add:
            appState.addBudgetItem(
                name: trimmed,
                planned: planned,
                budgetType: type,
                frequency: resolvedFrequency,
                dueDay: resolvedDueDay,
                dueWeekday: resolvedDueWeekday,
                dueDate: resolvedDueDate,
                targetAmount: resolvedTarget,
                deadline: resolvedDeadline
            )
        case .edit(let id):
            appState.updateBudgetItem(
                id: id,
                name: trimmed,
                planned: planned,
                budgetType: type,
                frequency: resolvedFrequency,
                dueDay: resolvedDueDay,
                dueWeekday: resolvedDueWeekday,
                dueDate: resolvedDueDate,
                targetAmount: resolvedTarget,
                deadline: resolvedDeadline
            )
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index]
    }
}

#Preview {
    NavigationStack {
        BudgetPlanView()
            .environmentObject(AppState())
    }
}
