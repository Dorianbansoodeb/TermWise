import React, { useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Card } from './Card';
import { useTheme } from '../theme/useTheme';
import type { ThemePalette } from '../theme/tokens';
import { SPACING } from '../theme/tokens';
import { formatCurrency } from '../utils/format';
import {
  recurringBillsForMonth,
  totalBudgeted,
  totalExpensesThisMonth,
  unallocatedRow,
  variableSpent
} from '../utils/financeCalculator';
import type { BudgetItem, TransactionItem } from '../types/models';

interface MonthlySnapshotCardProps {
  transactions: TransactionItem[];
  budgetItems: BudgetItem[];
  availableToBudget: number;
  savingsTarget: number;
  referenceDate: Date;
}

export function MonthlySnapshotCard({
  transactions,
  budgetItems,
  availableToBudget,
  savingsTarget,
  referenceDate
}: MonthlySnapshotCardProps) {
  const theme = useTheme();
  const totalBudgetedValue = totalBudgeted(budgetItems);
  const actualSpending = totalExpensesThisMonth(transactions, referenceDate);
  const varUsed = variableSpent(transactions, budgetItems, referenceDate);
  const bills = useMemo(
    () => recurringBillsForMonth(budgetItems, transactions, referenceDate),
    [budgetItems, transactions, referenceDate]
  );
  const paidCount = bills.filter((b) => b.status === 'paid').length;
  const planRow = unallocatedRow(availableToBudget, totalBudgetedValue, savingsTarget);

  return (
    <Card>
      <Text style={[styles.title, { color: theme.text }]}>Monthly Snapshot</Text>
      <Text style={[styles.subtitle, { color: theme.textMuted }]}>
        At-a-glance totals for this calendar month.
      </Text>
      <SnapshotRow label="Available to Budget" value={formatCurrency(availableToBudget)} theme={theme} />
      <SnapshotRow label="Total Budgeted" value={formatCurrency(totalBudgetedValue)} theme={theme} />
      <SnapshotRow label="Savings Target" value={formatCurrency(savingsTarget)} theme={theme} />
      <SnapshotRow label="Actual Spending" value={formatCurrency(actualSpending)} theme={theme} />
      <SnapshotRow
        label={planRow.label}
        value={formatCurrency(planRow.value)}
        theme={theme}
        positive={!planRow.isOver}
        danger={planRow.isOver}
      />
      <SnapshotRow label="Variable Spending Used" value={formatCurrency(varUsed)} theme={theme} />
      <SnapshotRow
        label="Recurring Bills Paid"
        value={`${paidCount} of ${bills.length}`}
        theme={theme}
      />
    </Card>
  );
}

function SnapshotRow({
  label,
  value,
  theme,
  positive,
  danger
}: {
  label: string;
  value: string;
  theme: ThemePalette;
  positive?: boolean;
  danger?: boolean;
}) {
  const color = danger ? theme.danger : positive ? theme.positive : theme.text;
  return (
    <View style={styles.row}>
      <Text style={[styles.rowLabel, { color: theme.textMuted }]}>{label}</Text>
      <Text style={[styles.rowValue, { color }]}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  title: {
    fontSize: 16,
    fontWeight: '700'
  },
  subtitle: {
    fontSize: 12,
    marginTop: 2,
    marginBottom: SPACING.md
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 6
  },
  rowLabel: {
    fontSize: 14,
    flex: 1,
    marginRight: SPACING.sm
  },
  rowValue: {
    fontSize: 14,
    fontWeight: '600'
  }
});
