import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';
import { Card } from './Card';
import { PrimaryButton } from './PrimaryButton';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { formatCurrency, formatPercent } from '../utils/format';

const RATE_OPTIONS = [0.05, 0.1, 0.15, 0.2, 0.25];

interface SavingsTargetCardProps {
  availableToBudget: number;
  savingsTarget: number;
  desiredSavingsRate: number;
  customSavingsTarget: number | undefined;
  onSelectRate: (rate: number) => void;
  onSaveCustomTarget: (amount: number) => void;
  onClearCustomTarget: () => void;
}

export function SavingsTargetCard({
  availableToBudget,
  savingsTarget,
  desiredSavingsRate,
  customSavingsTarget,
  onSelectRate,
  onSaveCustomTarget,
  onClearCustomTarget
}: SavingsTargetCardProps) {
  const theme = useTheme();
  const ratio =
    availableToBudget > 0 ? Math.min(1, Math.max(0, savingsTarget / availableToBudget)) : 0;

  const [draft, setDraft] = useState(formatDraft(customSavingsTarget));
  useEffect(() => {
    setDraft(formatDraft(customSavingsTarget));
  }, [customSavingsTarget]);

  return (
    <Card>
      <Text style={[styles.title, { color: theme.text }]}>Savings Target</Text>
      <Text style={[styles.helper, { color: theme.textMuted }]}>
        Money you plan to keep this month before any flexible spending.
      </Text>
      <Text style={[styles.amount, { color: theme.text }]}>{formatCurrency(savingsTarget)}</Text>
      <Text style={[styles.subtle, { color: theme.textMuted }]}>
        {formatPercent(ratio, 0)} of {formatCurrency(availableToBudget)} available
        {' '}({formatPercent(desiredSavingsRate, 0)} default rate)
      </Text>

      <View style={[styles.divider, { backgroundColor: theme.border }]} />

      <Text style={[styles.sectionLabel, { color: theme.textMuted }]}>Savings Rate</Text>
      <Text style={[styles.helper, { color: theme.textMuted, marginTop: 0 }]}>
        Default percentage of Available to Budget reserved for savings. A custom dollar amount
        below overrides this rate.
      </Text>
      <View style={styles.rateRow}>
        {RATE_OPTIONS.map((rate) => {
          const selected =
            customSavingsTarget == null && Math.abs(rate - desiredSavingsRate) < 0.001;
          return (
            <PrimaryButton
              key={rate}
              title={formatPercent(rate, 0)}
              variant={selected ? 'primary' : 'secondary'}
              onPress={() => onSelectRate(rate)}
              style={{ flex: 1 }}
            />
          );
        })}
      </View>

      <Text style={[styles.sectionLabel, { color: theme.textMuted, marginTop: SPACING.md }]}>
        Custom dollar savings target
      </Text>
      <TextInput
        value={draft}
        onChangeText={setDraft}
        keyboardType="decimal-pad"
        style={[
          styles.input,
          {
            color: theme.text,
            borderColor: theme.border,
            backgroundColor: theme.surface
          }
        ]}
        placeholder="Leave blank to use rate"
        placeholderTextColor={theme.textMuted}
      />
      <View style={styles.rateRow}>
        <PrimaryButton
          title="Save Custom Target"
          variant="primary"
          style={{ flex: 1 }}
          onPress={() => {
            const trimmed = draft.trim();
            if (trimmed === '') {
              onClearCustomTarget();
              return;
            }
            const value = parseFloat(trimmed);
            if (Number.isFinite(value)) onSaveCustomTarget(Math.max(0, value));
          }}
        />
        <PrimaryButton
          title="Clear"
          variant="ghost"
          style={{ flex: 1 }}
          onPress={() => {
            setDraft('');
            onClearCustomTarget();
          }}
        />
      </View>
    </Card>
  );
}

function formatDraft(value: number | undefined): string {
  if (value === undefined || !Number.isFinite(value)) return '';
  return value.toFixed(0);
}

const styles = StyleSheet.create({
  title: {
    fontSize: 16,
    fontWeight: '700'
  },
  helper: {
    fontSize: 12,
    marginTop: 2
  },
  amount: {
    fontSize: 28,
    fontWeight: '800',
    marginTop: SPACING.sm
  },
  subtle: {
    fontSize: 12,
    marginTop: 4
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    marginVertical: SPACING.md
  },
  sectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    marginBottom: SPACING.xs
  },
  rateRow: {
    flexDirection: 'row',
    gap: SPACING.sm
  },
  input: {
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm + 2,
    marginBottom: SPACING.sm,
    fontSize: 15
  }
});
