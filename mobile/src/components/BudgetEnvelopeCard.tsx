import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Card } from './Card';
import { useTheme } from '../theme/useTheme';
import { SPACING } from '../theme/tokens';
import { formatCurrency } from '../utils/format';
import {
  budgetDifference,
  reserveNotBudgeted,
  totalBudgeted,
  unallocatedRow
} from '../utils/financeCalculator';
import type { BudgetItem } from '../types/models';

interface BudgetEnvelopeCardProps {
  totalIncome: number;
  availableToBudget: number;
  savingsTarget: number;
  budgetItems: BudgetItem[];
}

export function BudgetEnvelopeCard({
  totalIncome,
  availableToBudget,
  savingsTarget,
  budgetItems
}: BudgetEnvelopeCardProps) {
  const theme = useTheme();
  const totalBudgetedValue = totalBudgeted(budgetItems, savingsTarget);
  const diff = budgetDifference(availableToBudget, totalBudgetedValue);
  const reserve = reserveNotBudgeted(totalIncome, availableToBudget);
  const row = unallocatedRow(availableToBudget, totalBudgetedValue);

  return (
    <Card>
      <Text style={[styles.title, { color: theme.text }]}>Budget Envelope</Text>
      <Text style={[styles.subtitle, { color: theme.textMuted }]}>
        How your income flows through the budget this month.
      </Text>
      <Row label="Total Income" value={formatCurrency(totalIncome)} muted />
      <Row label="Available to Budget" value={formatCurrency(availableToBudget)} emphasis />
      <Row label="Reserve / Not Budgeted" value={formatCurrency(reserve)} muted />
      <View style={[styles.divider, { backgroundColor: theme.border }]} />
      <Row label="Total Budgeted" value={formatCurrency(totalBudgetedValue)} />
      <Row
        label={row.label}
        value={formatCurrency(row.value)}
        tone={row.isOver ? 'danger' : 'positive'}
      />
      <Text style={[styles.helper, { color: theme.textMuted }]}>
        Difference {formatCurrency(Math.abs(diff))} {diff >= 0 ? 'still to allocate' : 'over-allocated'}.
      </Text>
    </Card>
  );
}

interface RowProps {
  label: string;
  value: string;
  muted?: boolean;
  emphasis?: boolean;
  tone?: 'positive' | 'danger';
}

function Row({ label, value, muted, emphasis, tone }: RowProps) {
  const theme = useTheme();
  const color =
    tone === 'danger'
      ? theme.danger
      : tone === 'positive'
        ? theme.positive
        : muted
          ? theme.textMuted
          : theme.text;
  return (
    <View style={styles.row}>
      <Text style={[styles.rowLabel, { color: muted ? theme.textMuted : theme.text }]}>{label}</Text>
      <Text
        style={[
          styles.rowValue,
          {
            color,
            fontWeight: emphasis || tone ? '700' : '600'
          }
        ]}
      >
        {value}
      </Text>
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
    fontSize: 14
  },
  rowValue: {
    fontSize: 14
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    marginVertical: SPACING.sm
  },
  helper: {
    fontSize: 11,
    marginTop: SPACING.sm
  }
});
