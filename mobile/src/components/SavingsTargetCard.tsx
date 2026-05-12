import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Card } from './Card';
import { useTheme } from '../theme/useTheme';
import { SPACING } from '../theme/tokens';
import { formatCurrency, formatPercent } from '../utils/format';

interface SavingsTargetCardProps {
  availableToBudget: number;
  savingsTarget: number;
  desiredSavingsRate: number;
}

export function SavingsTargetCard({
  availableToBudget,
  savingsTarget,
  desiredSavingsRate
}: SavingsTargetCardProps) {
  const theme = useTheme();
  const ratio =
    availableToBudget > 0 ? Math.min(1, Math.max(0, savingsTarget / availableToBudget)) : 0;
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
    </Card>
  );
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
  }
});
