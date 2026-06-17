import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { PillBadge } from './PillBadge';
import { RADIUS, SPACING } from '../theme/tokens';
import type { RecurringBill } from '../types/models';

interface BillRowProps {
  bill: RecurringBill;
  onMarkAsPaid: () => void;
  onEdit?: () => void;
}

export function BillRow({ bill, onMarkAsPaid, onEdit }: BillRowProps) {
  const theme = useTheme();
  const { formatMoney } = useAppState();
  const progress = bill.plannedAmount > 0 ? Math.min(1, bill.actualPaid / bill.plannedAmount) : 0;

  const badgeTone =
    bill.status === 'paid'
      ? 'positive'
      : bill.status === 'partial'
        ? 'warning'
        : bill.status === 'overdue'
          ? 'danger'
          : 'warning';
  const badgeLabel =
    bill.status === 'paid'
      ? 'Paid'
      : bill.status === 'partial'
        ? 'Partially Paid'
        : bill.status === 'overdue'
          ? 'Overdue'
          : 'Upcoming';

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: theme.surface, borderColor: theme.border }
      ]}
    >
      <View style={styles.header}>
        <View style={styles.left}>
          <Text style={[styles.category, { color: theme.text }]}>{bill.category}</Text>
          <Text style={[styles.due, { color: theme.textMuted }]}>
            {bill.dueDay ? `Due day ${bill.dueDay}` : 'No due day'} ·{' '}
            {formatMoney(bill.actualPaid, { compact: true })} of{' '}
            {formatMoney(bill.plannedAmount, { compact: true })}
          </Text>
        </View>
        <PillBadge label={badgeLabel} tone={badgeTone} />
      </View>

      <View style={[styles.track, { backgroundColor: theme.surfaceMuted }]}>
        <View
          style={[
            styles.fill,
            { width: `${progress * 100}%`, backgroundColor: theme.positive }
          ]}
        />
      </View>

      <View style={styles.footer}>
        {bill.status !== 'paid' ? (
          <Pressable
            onPress={onMarkAsPaid}
            style={({ pressed }) => [
              styles.actionBtn,
              { borderColor: theme.border, opacity: pressed ? 0.7 : 1 }
            ]}
          >
            <Text style={[styles.actionLabel, { color: theme.text }]}>Mark as Paid</Text>
          </Pressable>
        ) : (
          <View />
        )}
        {onEdit ? (
          <Pressable
            onPress={onEdit}
            style={({ pressed }) => [
              styles.actionBtn,
              { borderColor: theme.border, opacity: pressed ? 0.7 : 1 }
            ]}
          >
            <Text style={[styles.actionLabel, { color: theme.text }]}>Edit</Text>
          </Pressable>
        ) : null}
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
  category: {
    fontSize: 15,
    fontWeight: '700'
  },
  due: {
    fontSize: 12,
    marginTop: 2
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
    marginTop: SPACING.sm,
    gap: SPACING.sm
  },
  actionBtn: {
    paddingVertical: SPACING.xs + 2,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.pill,
    borderWidth: 1
  },
  actionLabel: {
    fontSize: 12,
    fontWeight: '600'
  }
});
