import React, { useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Card } from './Card';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import type { ThemePalette } from '../theme/tokens';
import { SPACING } from '../theme/tokens';
import {
  recurringBillsForMonth,
  totalBudgeted,
  totalExpensesThisMonth,
  variableSpent
} from '../utils/financeCalculator';
import type { BudgetItem, TransactionItem } from '../types/models';

interface MonthlySnapshotCardProps {
  transactions: TransactionItem[];
  budgetItems: BudgetItem[];
  referenceDate: Date;
}

export function MonthlySnapshotCard({
  transactions,
  budgetItems,
  referenceDate
}: MonthlySnapshotCardProps) {
  const theme = useTheme();
  const { formatMoney } = useAppState();
  const totalBudgetedValue = totalBudgeted(budgetItems);
  const actualSpending = totalExpensesThisMonth(transactions, referenceDate);
  const varUsed = variableSpent(transactions, budgetItems, referenceDate);
  const bills = useMemo(
    () => recurringBillsForMonth(budgetItems, transactions, referenceDate),
    [budgetItems, transactions, referenceDate]
  );
  const paidCount = bills.filter((b) => b.status === 'paid').length;
  // Snapshot "Remaining Budget / Over Spent" compares actual spending to the
  // planned budget — Savings Target is intentionally absent so it cannot
  // skew the difference.
  const remaining = totalBudgetedValue - actualSpending;
  const isOverSpent = remaining < 0;

  return (
    <Card>
      <Text style={[styles.title, { color: theme.text }]}>Monthly Snapshot</Text>
      <Text style={[styles.subtitle, { color: theme.textMuted }]}>
        At-a-glance totals for this calendar month.
      </Text>
      <SnapshotRow label="Total Budgeted" value={formatMoney(totalBudgetedValue)} theme={theme} />
      <SnapshotRow label="Actual Spending" value={formatMoney(actualSpending)} theme={theme} />
      <SnapshotRow
        label={isOverSpent ? 'Over Spent' : 'Remaining Budget'}
        value={formatMoney(Math.abs(remaining))}
        theme={theme}
        positive={!isOverSpent}
        danger={isOverSpent}
      />
      <SnapshotRow label="Variable Spending Used" value={formatMoney(varUsed)} theme={theme} />
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
