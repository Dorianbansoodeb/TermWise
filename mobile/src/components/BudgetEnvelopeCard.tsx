import React, { useEffect, useMemo, useState } from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';
import { Card } from './Card';
import { PrimaryButton } from './PrimaryButton';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import {
  availableToBudgetWarning,
  budgetDifference,
  budgetingOverIncomeAmount,
  reserveNotBudgeted,
  totalBudgeted,
  unallocatedRow
} from '../utils/financeCalculator';
import type { BudgetItem } from '../types/models';

interface BudgetEnvelopeCardProps {
  totalIncome: number;
  availableToBudget: number;
  budgetItems: BudgetItem[];
  onSaveAvailableToBudget: (amount: number) => void;
}

export function BudgetEnvelopeCard({
  totalIncome,
  availableToBudget,
  budgetItems,
  onSaveAvailableToBudget
}: BudgetEnvelopeCardProps) {
  const theme = useTheme();
  const { formatMoney } = useAppState();
  const totalBudgetedValue = totalBudgeted(budgetItems);
  const diff = budgetDifference(availableToBudget, totalBudgetedValue);
  const reserve = reserveNotBudgeted(totalIncome, availableToBudget);
  const overIncome = budgetingOverIncomeAmount(totalIncome, availableToBudget);
  const isOverIncome = overIncome > 0;
  const row = unallocatedRow(availableToBudget, totalBudgetedValue);

  const [draft, setDraft] = useState(formatDraft(availableToBudget));
  useEffect(() => {
    setDraft(formatDraft(availableToBudget));
  }, [availableToBudget]);

  const liveAvailable = useMemo(() => {
    const trimmed = draft.trim();
    if (trimmed === '') return availableToBudget;
    const parsed = parseFloat(trimmed);
    return Number.isFinite(parsed) ? Math.max(0, parsed) : availableToBudget;
  }, [draft, availableToBudget]);

  const overIncomeWarning = useMemo(
    () => availableToBudgetWarning(totalIncome, liveAvailable),
    [totalIncome, liveAvailable]
  );

  const onSave = () => {
    const trimmed = draft.trim();
    const value = trimmed === '' ? 0 : parseFloat(trimmed);
    if (!Number.isFinite(value)) return;
    onSaveAvailableToBudget(Math.max(0, value));
  };

  return (
    <Card>
      <Text style={[styles.title, { color: theme.text }]}>Budget Envelope</Text>
      <Text style={[styles.subtitle, { color: theme.textMuted }]}>
        How your income flows through the budget this month.
      </Text>

      <Row label="Total Income" value={formatMoney(totalIncome)} muted />

      <Text style={[styles.editorLabel, { color: theme.textMuted }]}>Available to Budget</Text>
      <Text style={[styles.editorHelper, { color: theme.textMuted }]}>
        Choose how much of your income you want to plan with this month.
      </Text>
      <TextInput
        value={draft}
        onChangeText={setDraft}
        keyboardType="decimal-pad"
        style={[
          styles.input,
          {
            color: theme.text,
            borderColor: overIncomeWarning ? theme.danger : theme.border,
            backgroundColor: theme.surface
          }
        ]}
        placeholder="0"
        placeholderTextColor={theme.textMuted}
      />
      {overIncomeWarning ? (
        <Text style={[styles.warningText, { color: theme.danger }]}>{overIncomeWarning}</Text>
      ) : null}
      <PrimaryButton title="Save Available to Budget" onPress={onSave} style={{ marginBottom: SPACING.md }} />

      {isOverIncome ? (
        <Row
          label="Budgeting Over Income"
          value={formatMoney(overIncome)}
          tone="danger"
        />
      ) : (
        <Row label="Reserve / Not Budgeted" value={formatMoney(reserve)} muted />
      )}

      <View style={[styles.divider, { backgroundColor: theme.border }]} />
      <Row label="Total Budgeted" value={formatMoney(totalBudgetedValue)} />
      <Row
        label={row.label}
        value={formatMoney(row.value)}
        tone={row.isOver ? 'danger' : 'positive'}
      />
      <Text style={[styles.helper, { color: theme.textMuted }]}>
        Difference {formatMoney(Math.abs(diff))}{' '}
        {diff >= 0 ? 'still to allocate' : 'over-allocated'}. Savings Target is shown
        separately and does not affect this difference.
      </Text>
    </Card>
  );
}

function formatDraft(value: number): string {
  if (!Number.isFinite(value)) return '';
  return value.toFixed(0);
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
    marginBottom: SPACING.sm
  },
  editorLabel: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    marginTop: SPACING.sm
  },
  editorHelper: {
    fontSize: 12,
    marginTop: 4,
    marginBottom: SPACING.xs
  },
  input: {
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm + 2,
    marginBottom: SPACING.sm,
    fontSize: 15
  },
  warningText: {
    fontSize: 12,
    fontWeight: '600',
    marginTop: -SPACING.xs,
    marginBottom: SPACING.sm,
    lineHeight: 16
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
