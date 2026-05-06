import SwiftUI

struct BudgetPlanView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var focusedCategoryId: UUID?
    @State private var editingCategoryIds: Set<UUID> = []
    @State private var showingAddTransactionSheet = false
    @State private var newCategoryName: String = ""
    @State private var newCategoryAmount: String = ""
    @State private var newCategoryHasDueDate = false
    @State private var newCategoryDueDay: Int = 1
    @State private var newCategoryDueRule: DueDateRule = .monthlyDay

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard
                tuitionSavingsCard

                ForEach($appState.budgetItems) { $item in
                    budgetCategoryCard(item: $item)
                }

                addCategoryCard
            }
            .padding()
        }
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
                            newCategoryHasDueDate = true
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

    private func budgetCategoryCard(item: Binding<BudgetItem>) -> some View {
        let id = item.wrappedValue.id
        let actual = appState.actualAmount(for: item.wrappedValue.category)
        let isEditing = editingCategoryIds.contains(id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.wrappedValue.category)
                    .font(.headline)
                Spacer()
                Text(actual > item.wrappedValue.planned ? "Over" : "On Track")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((actual > item.wrappedValue.planned ? Color.red : Color.green).opacity(0.15))
                    .clipShape(Capsule())
            }

            ProgressView(value: actual, total: max(1, item.wrappedValue.planned))
                .tint(actual > item.wrappedValue.planned ? .red : .blue)

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

            if let dueRule = item.wrappedValue.dueRule {
                HStack {
                    Text("Due date")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isEditing {
                        Picker("Rule", selection: Binding(
                            get: { item.wrappedValue.dueRule ?? .monthlyDay },
                            set: { item.wrappedValue.dueRule = $0 }
                        )) {
                            ForEach(DueDateRule.allCases) { rule in
                                Text(rule.label).tag(rule)
                            }
                        }
                        .pickerStyle(.menu)
                        if (item.wrappedValue.dueRule ?? .monthlyDay) != .endOfMonth {
                            Stepper("Due \(item.wrappedValue.dueDay ?? 1)", value: Binding(
                                get: { item.wrappedValue.dueDay ?? 1 },
                                set: { item.wrappedValue.dueDay = $0 }
                            ), in: 1...28)
                            .labelsHidden()
                        }
                    }
                    Text(dueDateSubtitle(rule: dueRule, day: item.wrappedValue.dueDay))
                        .font(.subheadline)
                }
            }

            HStack {
                Text("Actual")
                Spacer()
                Text(actual.formatted(appState.currencyFormatter))
                    .foregroundStyle(actual > item.wrappedValue.planned ? .red : .secondary)
            }

            Text("\(progressPercent(actual: actual, planned: item.wrappedValue.planned))% used")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
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

    private func progressPercent(actual: Double, planned: Double) -> Int {
        Int((actual / max(1, planned)) * 100)
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

            Toggle("Add monthly due date", isOn: $newCategoryHasDueDate)

            if newCategoryHasDueDate {
                Picker("Due schedule", selection: $newCategoryDueRule) {
                    ForEach(DueDateRule.allCases) { rule in
                        Text(rule.label).tag(rule)
                    }
                }
                .pickerStyle(.segmented)
                if newCategoryDueRule != .endOfMonth {
                    Stepper("Due day: \(newCategoryDueDay)", value: $newCategoryDueDay, in: 1...28)
                        .font(.subheadline)
                }
            }

            Button("Add Category") {
                appState.addBudgetCategory(
                    name: newCategoryName,
                    planned: Double(newCategoryAmount) ?? 0,
                    dueDay: newCategoryHasDueDate && newCategoryDueRule != .endOfMonth ? newCategoryDueDay : nil,
                    dueRule: newCategoryHasDueDate ? newCategoryDueRule : nil
                )
                newCategoryName = ""
                newCategoryAmount = ""
                newCategoryHasDueDate = false
                newCategoryDueDay = 1
                newCategoryDueRule = .monthlyDay
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

    private func dueDateSubtitle(rule: DueDateRule, day: Int?) -> String {
        switch rule {
        case .monthlyDay:
            return "Monthly • Day \(day ?? 1)"
        case .endOfMonth:
            return "End of month"
        case .biweekly:
            return "Biweekly • Day \(day ?? 1)"
        }
    }
}

#Preview {
    NavigationStack {
        BudgetPlanView()
            .environmentObject(AppState())
    }
}
