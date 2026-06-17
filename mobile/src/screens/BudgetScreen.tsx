import React, { useMemo, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { SPACING } from '../theme/tokens';
import { contentBottomPaddingForTabs } from '../navigation/constants';
import {
  recurringBillsForMonth,
  totalIncomeThisMonth,
  variableCategoryProgress
} from '../utils/financeCalculator';
import { BudgetEnvelopeCard } from '../components/BudgetEnvelopeCard';
import { SavingsTargetCard } from '../components/SavingsTargetCard';
import { MonthlySnapshotCard } from '../components/MonthlySnapshotCard';
import { BudgetPlanningPieCard } from '../components/BudgetPlanningPieCard';
import { Card } from '../components/Card';
import { BillRow } from '../components/BillRow';
import { AddBudgetItemSheet } from '../components/AddBudgetItemSheet';
import { EditRecurringBillSheet } from '../components/EditRecurringBillSheet';
import { VariableCategoryRow } from '../components/VariableCategoryRow';
import { EditVariableCategorySheet } from '../components/EditVariableCategorySheet';
import { PrimaryButton } from '../components/PrimaryButton';

export function BudgetScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const {
    transactions,
    budgetItems,
    settingsForMonth,
    availableToBudget,
    savingsTarget,
    markBillAsPaid,
    updateBudgetItem,
    addBudgetItem,
    removeBudgetItem,
    referenceDate,
    setAvailableToBudget,
    setSavingsTarget,
    setDesiredSavingsRate,
    resetToDemo
  } = useAppState();

  const [editingVariableId, setEditingVariableId] = useState<string | null>(null);
  const [editingBillId, setEditingBillId] = useState<string | null>(null);
  const [addBudgetItemOpen, setAddBudgetItemOpen] = useState(false);

  const totalIncome = totalIncomeThisMonth(transactions, referenceDate);
  const recurringBills = useMemo(
    () => recurringBillsForMonth(budgetItems, transactions, referenceDate),
    [budgetItems, transactions, referenceDate]
  );

  const variableItems = budgetItems.filter((b) => b.budgetType === 'variable');

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingBottom: contentBottomPaddingForTabs(insets.bottom) }
        ]}
        showsVerticalScrollIndicator={false}
      >
        <Text style={[styles.title, { color: theme.text }]}>Budget Plan</Text>

        <BudgetEnvelopeCard
          totalIncome={totalIncome}
          availableToBudget={availableToBudget}
          budgetItems={budgetItems}
          onSaveAvailableToBudget={setAvailableToBudget}
        />

        <SavingsTargetCard
          availableToBudget={availableToBudget}
          savingsTarget={savingsTarget}
          desiredSavingsRate={settingsForMonth.desiredSavingsRate}
          customSavingsTarget={settingsForMonth.customSavingsTarget}
          onSelectRate={(rate) => {
            if (settingsForMonth.customSavingsTarget !== undefined) {
              setSavingsTarget(undefined);
            }
            setDesiredSavingsRate(rate);
          }}
          onSaveCustomTarget={(amount) => setSavingsTarget(amount)}
          onClearCustomTarget={() => setSavingsTarget(undefined)}
        />

        <MonthlySnapshotCard
          transactions={transactions}
          budgetItems={budgetItems}
          referenceDate={referenceDate}
        />

        <PrimaryButton title="Add Budget Item" onPress={() => setAddBudgetItemOpen(true)} />

        <BudgetPlanningPieCard
          budgetItems={budgetItems}
          availableToBudget={availableToBudget}
          referenceDate={referenceDate}
        />

        <View>
          <Text style={[styles.section, { color: theme.text }]}>Recurring Bills</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Fixed monthly bills. Mark each one paid when you settle it; partial payments are
            supported.
          </Text>
          {recurringBills.length === 0 ? (
            <Card>
              <Text style={[styles.empty, { color: theme.textMuted }]}>No recurring bills yet.</Text>
            </Card>
          ) : (
            recurringBills.map((bill) => (
              <BillRow
                key={bill.id}
                bill={bill}
                onMarkAsPaid={() => markBillAsPaid(bill.id)}
                onEdit={() => setEditingBillId(bill.id)}
              />
            ))
          )}
        </View>

        <View>
          <Text style={[styles.section, { color: theme.text }]}>Variable Spending</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Flexible categories. Each card shows progress toward its monthly limit.
          </Text>
          {variableItems.length === 0 ? (
            <Card>
              <Text style={[styles.empty, { color: theme.textMuted }]}>
                Add a variable category to track flexible spending.
              </Text>
            </Card>
          ) : (
            variableItems.map((item) => (
              <VariableCategoryRow
                key={item.id}
                item={item}
                progress={variableCategoryProgress(item, transactions, referenceDate)}
                onEdit={() => setEditingVariableId(item.id)}
              />
            ))
          )}
        </View>

        <Card>
          <Text style={[styles.section, { color: theme.text }]}>Data</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Reset the local snapshot to the bundled student demo. This clears AsyncStorage.
          </Text>
          <PrimaryButton title="Reset to Demo Data" variant="danger" onPress={resetToDemo} />
        </Card>
      </ScrollView>

      <AddBudgetItemSheet
        visible={addBudgetItemOpen}
        onClose={() => setAddBudgetItemOpen(false)}
        onAdd={(draft) => addBudgetItem(draft)}
      />

      <EditVariableCategorySheet
        visible={editingVariableId !== null}
        item={variableItems.find((b) => b.id === editingVariableId) ?? null}
        onCancel={() => setEditingVariableId(null)}
        onSave={(patch) => {
          if (editingVariableId) updateBudgetItem(editingVariableId, patch);
          setEditingVariableId(null);
        }}
        onDelete={() => {
          if (editingVariableId) removeBudgetItem(editingVariableId);
          setEditingVariableId(null);
        }}
      />

      <EditRecurringBillSheet
        visible={editingBillId !== null}
        item={budgetItems.find((b) => b.id === editingBillId && b.budgetType === 'fixed') ?? null}
        onCancel={() => setEditingBillId(null)}
        onSave={(patch) => {
          if (editingBillId) updateBudgetItem(editingBillId, patch);
          setEditingBillId(null);
        }}
        onDelete={() => {
          if (editingBillId) removeBudgetItem(editingBillId);
          setEditingBillId(null);
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1
  },
  scroll: {
    padding: SPACING.lg,
    gap: SPACING.lg
  },
  title: {
    fontSize: 26,
    fontWeight: '800'
  },
  section: {
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 4
  },
  helper: {
    fontSize: 12,
    marginBottom: SPACING.sm
  },
  empty: {
    fontSize: 12,
    paddingVertical: SPACING.sm
  }
});
