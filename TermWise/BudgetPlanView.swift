import SwiftUI

struct BudgetPlanView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAddTransactionSheet = false
    @State private var budgetEditor: BudgetItemEditorContext?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                budgetEnvelopeCard
                savingsTargetCard
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

    /// Budget Envelope card — explains how the user's income is split between the budget envelope
    /// they chose to plan with this month and the income they're keeping in reserve.
    ///
    /// Source-of-truth rule (drives every row except Total Income):
    /// - **Total Income** is *informational only*. It never drives budget calculations.
    /// - **Available to Budget** is the editable, user-controlled source of truth. All other rows
    ///   (Reserve / Not Budgeted, Savings Target, Total Budgeted, Unallocated / Over Budget) are
    ///   derived from it.
    ///
    /// Rows (in order):
    /// 1. Total Income          (informational — caption says so)
    /// 2. Available to Budget   (editable)
    /// 3. Reserve / Not Budgeted = Total Income − Available to Budget (clamped at 0)
    /// 4. Savings Target        = mirrors the Savings Target card (rate or custom)
    /// 5. Total Budgeted        = sum of all non-hidden planned allocations + Savings Target
    /// 6. Unallocated Budget OR Over Budget By
    private var budgetEnvelopeCard: some View {
        let unallocated = FinanceBudgetAllocation.unallocatedRow(
            availableToBudget: appState.availableToBudget,
            totalBudgeted: appState.totalBudgeted
        )
        let isOverIncome = appState.availableToBudget > appState.totalIncome && appState.totalIncome > 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Budget Envelope")
                .font(.headline)

            // 1. Total Income — informational only. The value is rendered in `.secondary` so it
            //    doesn't read as "the budget amount", and the caption below states it explicitly.
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Total Income")
                    Spacer()
                    Text(appState.totalIncome.formatted(appState.currencyFormatter))
                        .foregroundStyle(.secondary)
                }
                Text("Informational only — does not control your budget.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 2. Available to Budget — editable, with the new spec-mandated helper text below.
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Available to Budget")
                    Spacer()
                    TextField(
                        "Amount",
                        value: Binding(
                            get: { appState.availableToBudget },
                            set: { appState.setAvailableToBudgetForCurrentMonth($0) }
                        ),
                        format: .number
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                }
                Text("Your budget is based on Available to Budget, not your full income.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 3. Reserve / Not Budgeted (always shown, even when 0).
            metricRow("Reserve / Not Budgeted", appState.reserveNotBudgeted)

            // 4. Savings Target — read-only mirror of the Savings Target card below.
            metricRow("Savings Target", appState.savingsTargetThisMonth)

            // 5. Total Budgeted (planned allocations + savings target — never income, never spending).
            metricRow("Total Budgeted", appState.totalBudgeted)

            // 6. Unallocated Budget OR Over Budget By
            metricRow(
                unallocated.label,
                unallocated.value,
                emphasize: true,
                forceColor: unallocated.isOver ? .red : .green
            )

            // Inline warning when the user budgets more than they actually earned.
            if isOverIncome {
                Text("You are budgeting more than your recorded income.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Small explanation footer reinforcing the Income vs Available distinction.
            Text("Income is what you receive. Available to Budget is what you choose to plan with.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    /// Savings Target card — controls how much of *Available to Budget* the user plans to set
    /// aside this month. The chosen amount flows directly into `appState.savingsTargetThisMonth`,
    /// which counts toward `totalBudgeted` and the Monthly Snapshot's planned bucket.
    ///
    /// Behavior:
    /// - 10% / 15% / 20%: sets `desiredSavingsRate` and clears any custom dollar override.
    /// - Other: persists a per-month dollar override via `setCustomSavingsTargetForCurrentMonth`.
    private var savingsTargetCard: some View {
        SavingsTargetCard()
            .environmentObject(appState)
    }

    /// Monthly Snapshot card — compares the planned budget against the user's actual spending
    /// for the **current calendar month only**, and surfaces a quick variable / recurring split.
    ///
    /// Rows (in order):
    /// 1. Planned Budget          = sum of non-hidden item.planned + savings target
    /// 2. Actual Spending         = current-month net expenses from transactions
    /// 3. Savings Target          = the envelope-level savings number chosen on the Savings Target card
    /// 4. Remaining Budget OR Over Spent (signed: positive = remaining, negative = over)
    /// 5. Variable Spending Used  = "$spent / $planned" for variable items only
    /// 6. Recurring Bills Paid    = "X of Y paid" for `.fixed` items only
    private var monthlySnapshotCard: some View {
        let snapshot = appState.monthlySnapshot
        let variableUsedColor: Color = snapshot.isVariableOverPlanned ? .red : .green
        let recurringColor: Color = snapshot.allRecurringBillsPaid ? .green : .secondary
        let formatter = appState.currencyFormatter

        return VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Snapshot")
                .font(.headline)

            // 1. Planned Budget
            metricRow("Planned Budget", snapshot.plannedBudget)

            // 2. Actual Spending
            metricRow("Actual Spending", snapshot.actualSpending)

            // 3. Savings Target — read-only mirror of the Savings Target card.
            metricRow("Savings Target", snapshot.savingsTarget)

            // 4. Remaining Budget OR Over Spent
            metricRow(
                snapshot.isOverSpent ? "Over Spent" : "Remaining Budget",
                abs(snapshot.remaining),
                emphasize: true,
                forceColor: snapshot.isOverSpent ? .red : .green
            )

            // 5. Variable Spending Used  ($spent / $planned, "—" when no variable items)
            HStack {
                Text("Variable Spending Used")
                Spacer()
                if snapshot.variablePlanned > 0 {
                    Text("\(snapshot.variableSpent.formatted(formatter)) / \(snapshot.variablePlanned.formatted(formatter))")
                        .foregroundStyle(variableUsedColor)
                        .fontWeight(.semibold)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }

            // 6. Recurring Bills Paid  ("X of Y paid", "—" when none scheduled)
            HStack {
                Text("Recurring Bills Paid")
                Spacer()
                if snapshot.recurringBillsTotal > 0 {
                    Text("\(snapshot.recurringBillsPaid) of \(snapshot.recurringBillsTotal) paid")
                        .foregroundStyle(recurringColor)
                        .fontWeight(.semibold)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }

            Text("Snapshot compares your planned budget against what you actually spent this month.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

// MARK: - Savings Target card

/// Inline savings-rate selector that lives on the Budget Plan screen (replaces the old "Budget
/// Goals" section that used to live on the Profile tab). Selecting 10/15/20% updates
/// `appState.desiredSavingsRate` and clears any custom override; selecting **Other** lets the user
/// type a custom dollar amount that is persisted per month via `customSavingsTargetByMonth`.
private struct SavingsTargetCard: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedOption: SavingsRateOption = .fifteen
    @State private var customAmountText: String = ""
    @State private var didLoadInitialValues = false

    private enum SavingsRateOption: String, CaseIterable, Identifiable {
        case ten, fifteen, twenty, other
        var id: String { rawValue }

        var label: String {
            switch self {
            case .ten: return "10%"
            case .fifteen: return "15%"
            case .twenty: return "20%"
            case .other: return "Other"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Savings Target")
                .font(.headline)

            // Available to Budget — read-only mirror so the user can see what the percentage acts on.
            HStack {
                Text("Available to Budget")
                Spacer()
                Text(appState.availableToBudget.formatted(appState.currencyFormatter))
                    .foregroundStyle(.secondary)
            }

            Text("How much would you like to save from your budget?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Target savings rate", selection: $selectedOption) {
                ForEach(SavingsRateOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedOption) {
                applySelection()
            }

            if selectedOption == .other {
                HStack {
                    Text("Custom amount")
                    Spacer()
                    TextField("Amount", text: $customAmountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                        .onChange(of: customAmountText) {
                            applyCustomAmount()
                        }
                }
            }

            // Resolved savings target — what actually flows into Total Budgeted.
            HStack {
                Text("Savings Target")
                    .fontWeight(.semibold)
                Spacer()
                Text(appState.savingsTargetThisMonth.formatted(appState.currencyFormatter))
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }

            if selectedOption != .other {
                Text("Savings Target = Available to Budget × \(Int(appState.desiredSavingsRate))%.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Custom savings amount counts toward Total Budgeted for this month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .onAppear { loadInitialValuesIfNeeded() }
    }

    private func loadInitialValuesIfNeeded() {
        guard !didLoadInitialValues else { return }
        didLoadInitialValues = true

        if let custom = appState.customSavingsTargetByMonth[appState.currentMonthKey] {
            selectedOption = .other
            customAmountText = formatAmount(custom)
        } else {
            selectedOption = closestStandardRate(to: appState.desiredSavingsRate)
        }
    }

    private func applySelection() {
        switch selectedOption {
        case .ten:
            appState.setSavingsRate(10)
        case .fifteen:
            appState.setSavingsRate(15)
        case .twenty:
            appState.setSavingsRate(20)
        case .other:
            // Seed the custom field with the current rate-derived amount so the value is sensible.
            if appState.customSavingsTargetByMonth[appState.currentMonthKey] == nil {
                let seeded = appState.availableToBudget * (appState.desiredSavingsRate / 100)
                customAmountText = formatAmount(seeded)
                appState.setCustomSavingsTargetForCurrentMonth(seeded)
            }
        }
    }

    private func applyCustomAmount() {
        guard selectedOption == .other else { return }
        let parsed = Double(customAmountText) ?? 0
        appState.setCustomSavingsTargetForCurrentMonth(parsed)
    }

    private func closestStandardRate(to value: Double) -> SavingsRateOption {
        if abs(value - 10) < 0.5 { return .ten }
        if abs(value - 20) < 0.5 { return .twenty }
        // Default and "anything else" both fall to 15% — there's no Other option without a custom override.
        return .fifteen
    }

    private func formatAmount(_ amount: Double) -> String {
        if amount.rounded() == amount {
            return String(Int(amount))
        }
        return String(format: "%g", amount)
    }
}

#Preview {
    NavigationStack {
        BudgetPlanView()
            .environmentObject(AppState())
    }
}
