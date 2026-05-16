import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { PillBadge } from './PillBadge';
import { RADIUS, SPACING } from '../theme/tokens';
import { colorForCategory } from '../utils/categories';
import { formatPercent } from '../utils/format';
import type { VariableCategoryProgress } from '../utils/financeCalculator';
import type { BudgetItem } from '../types/models';

interface VariableCategoryRowProps {
  item: BudgetItem;
  progress: VariableCategoryProgress;
  onEdit: () => void;
}

/// Variable Spending card. Mirrors the layout of `BillRow` (header + thin
/// progress track + Edit action) but uses the per-category status from
/// `variableCategoryProgress` instead of paid/partial/unpaid bill logic.
export function VariableCategoryRow({ item, progress, onEdit }: VariableCategoryRowProps) {
  const theme = useTheme();
  const { formatMoney } = useAppState();
  const isOver = progress.status === 'overBudget';
  const fillColor = isOver ? theme.danger : theme.positive;
  const dotColor = colorForCategory(item.category);

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: theme.surface, borderColor: theme.border }
      ]}
    >
      <View style={styles.header}>
        <View style={styles.left}>
          <View style={styles.titleRow}>
            <View style={[styles.dot, { backgroundColor: dotColor }]} />
            <Text style={[styles.category, { color: theme.text }]} numberOfLines={1}>
              {item.category}
            </Text>
          </View>
          <Text style={[styles.meta, { color: theme.textMuted }]}>
            {formatMoney(progress.actual, { compact: true })} of{' '}
            {formatMoney(progress.planned, { compact: true })}
            {progress.planned > 0 ? ` · ${formatPercent(progress.percentUsed, 0)}` : ''}
          </Text>
        </View>
        <PillBadge label={isOver ? 'Over Budget' : 'On Track'} tone={isOver ? 'danger' : 'positive'} />
      </View>

      <View style={[styles.track, { backgroundColor: theme.surfaceMuted }]}>
        <View
          style={[
            styles.fill,
            { width: `${progress.displayProgress * 100}%`, backgroundColor: fillColor }
          ]}
        />
      </View>

      <View style={styles.footer}>
        <Text
          style={[
            styles.footerLabel,
            { color: isOver ? theme.danger : theme.textMuted }
          ]}
        >
          {isOver
            ? `Over by ${formatMoney(progress.over)}`
            : `${formatMoney(progress.remaining)} left this month`}
        </Text>
        <Pressable
          onPress={onEdit}
          style={({ pressed }) => [
            styles.editBtn,
            { borderColor: theme.border, opacity: pressed ? 0.7 : 1 }
          ]}
        >
          <Text style={[styles.editLabel, { color: theme.text }]}>Edit</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    padding: SPACING.md,
    marginBottom: SPACING.sm
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.sm
  },
  left: {
    flex: 1,
    marginRight: SPACING.sm
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center'
  },
  dot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: SPACING.sm
  },
  category: {
    fontSize: 15,
    fontWeight: '700',
    flexShrink: 1
  },
  meta: {
    fontSize: 12,
    marginTop: 2,
    marginLeft: 10 + SPACING.sm
  },
  track: {
    height: 6,
    borderRadius: 3,
    overflow: 'hidden'
  },
  fill: {
    height: '100%'
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: SPACING.sm
  },
  footerLabel: {
    fontSize: 12,
    fontWeight: '600',
    flex: 1,
    marginRight: SPACING.sm
  },
  editBtn: {
    paddingVertical: SPACING.xs + 2,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.pill,
    borderWidth: 1
  },
  editLabel: {
    fontSize: 12,
    fontWeight: '600'
  }
});
