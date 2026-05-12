import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useTheme } from '../theme/useTheme';
import { PillBadge } from './PillBadge';
import { RADIUS, SPACING } from '../theme/tokens';
import type { RecurringBill } from '../types/models';
import { formatCurrency } from '../utils/format';

interface BillRowProps {
  bill: RecurringBill;
  onMarkAsPaid: () => void;
}

export function BillRow({ bill, onMarkAsPaid }: BillRowProps) {
  const theme = useTheme();
  const progress = bill.plannedAmount > 0 ? Math.min(1, bill.actualPaid / bill.plannedAmount) : 0;

  const badgeTone =
    bill.status === 'paid' ? 'positive' : bill.status === 'partial' ? 'warning' : 'neutral';
  const badgeLabel =
    bill.status === 'paid' ? 'Paid' : bill.status === 'partial' ? 'Partially Paid' : 'Unpaid';

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
            {formatCurrency(bill.actualPaid, { compact: true })} of{' '}
            {formatCurrency(bill.plannedAmount, { compact: true })}
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

      {bill.status !== 'paid' && (
        <Pressable
          onPress={onMarkAsPaid}
          style={({ pressed }) => [
            styles.markPaidBtn,
            { borderColor: theme.border, opacity: pressed ? 0.7 : 1 }
          ]}
        >
          <Text style={[styles.markPaidLabel, { color: theme.text }]}>Mark as Paid</Text>
        </Pressable>
      )}
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
  markPaidBtn: {
    marginTop: SPACING.sm,
    paddingVertical: SPACING.xs + 2,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.pill,
    borderWidth: 1,
    alignSelf: 'flex-start'
  },
  markPaidLabel: {
    fontSize: 12,
    fontWeight: '600'
  }
});
