import React, { useMemo, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { SPACING } from '../theme/tokens';
import {
  recurringBillsForMonth,
  totalIncomeThisMonth,
  variableCategoryProgress
} from '../utils/financeCalculator';
import { BudgetEnvelopeCard } from '../components/BudgetEnvelopeCard';
import { SavingsTargetCard } from '../components/SavingsTargetCard';
import { MonthlySnapshotCard } from '../components/MonthlySnapshotCard';
import { Card } from '../components/Card';
import { BillRow } from '../components/BillRow';
import { VariableCategoryRow } from '../components/VariableCategoryRow';
import { EditVariableCategorySheet } from '../components/EditVariableCategorySheet';
import { PrimaryButton } from '../components/PrimaryButton';
import { formatCurrency } from '../utils/format';
import { colorForCategory } from '../utils/categories';

export function BudgetScreen() {
  const theme = useTheme();
  const {
    transactions,
    budgetItems,
    settingsForMonth,
    availableToBudget,
    savingsTarget,
    markBillAsPaid,
    updateBudgetItem,
    referenceDate,
    setAvailableToBudget,
    setSavingsTarget,
    setDesiredSavingsRate,
    resetToDemo
  } = useAppState();

  const [editingId, setEditingId] = useState<string | null>(null);

  const totalIncome = totalIncomeThisMonth(transactions, referenceDate);
  const recurringBills = useMemo(
    () => recurringBillsForMonth(budgetItems, transactions, referenceDate),
    [budgetItems, transactions, referenceDate]
  );

  const variableItems = budgetItems.filter((b) => b.budgetType === 'variable');
  const savingsItems = budgetItems.filter((b) => b.budgetType === 'savings');

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
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
              <BillRow key={bill.id} bill={bill} onMarkAsPaid={() => markBillAsPaid(bill.id)} />
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
                onEdit={() => setEditingId(item.id)}
              />
            ))
          )}
        </View>

        <View>
          <Text style={[styles.section, { color: theme.text }]}>Savings Goals</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Long-term goals that contribute toward your Savings Target.
          </Text>
          <Card>
            {savingsItems.map((item, idx) => (
              <View
                key={item.id}
                style={[
                  styles.budgetRow,
                  idx > 0 && {
                    borderTopWidth: StyleSheet.hairlineWidth,
                    borderTopColor: theme.border
                  }
                ]}
              >
                <View style={[styles.dot, { backgroundColor: colorForCategory(item.category) }]} />
                <View style={{ flex: 1 }}>
                  <Text style={[styles.rowLabel, { color: theme.text }]}>{item.category}</Text>
                  {item.targetAmount && (
                    <Text style={[styles.rowSub, { color: theme.textMuted }]}>
                      Goal {formatCurrency(item.targetAmount, { compact: true })}
                    </Text>
                  )}
                </View>
                <Text style={[styles.rowValue, { color: theme.textMuted }]}>
                  {formatCurrency(item.planned, { compact: true })}/mo
                </Text>
              </View>
            ))}
            {savingsItems.length === 0 && (
              <Text style={[styles.empty, { color: theme.textMuted }]}>
                No savings goals yet.
              </Text>
            )}
          </Card>
        </View>

        <Card>
          <Text style={[styles.section, { color: theme.text }]}>Data</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Reset the local snapshot to the bundled student demo. This clears AsyncStorage.
          </Text>
          <PrimaryButton title="Reset to Demo Data" variant="danger" onPress={resetToDemo} />
        </Card>
      </ScrollView>

      <EditVariableCategorySheet
        visible={editingId !== null}
        item={variableItems.find((b) => b.id === editingId) ?? null}
        onCancel={() => setEditingId(null)}
        onSave={(patch) => {
          if (editingId) updateBudgetItem(editingId, patch);
          setEditingId(null);
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
    gap: SPACING.lg,
    paddingBottom: SPACING.xxl * 2
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
  budgetRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: SPACING.sm
  },
  dot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: SPACING.sm
  },
  rowLabel: {
    flex: 1,
    fontSize: 14,
    fontWeight: '600'
  },
  rowSub: {
    fontSize: 11,
    marginTop: 1
  },
  rowValue: {
    fontSize: 14,
    fontWeight: '600'
  },
  empty: {
    fontSize: 12,
    paddingVertical: SPACING.sm
  }
});
