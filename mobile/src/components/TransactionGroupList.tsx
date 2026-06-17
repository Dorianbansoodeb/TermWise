import React, { useRef } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { RectButton, Swipeable } from 'react-native-gesture-handler';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import type { TransactionGroup } from '../utils/financeCalculator';
import { netExpenseAmount } from '../utils/financeCalculator';
import { colorForCategory } from '../utils/categories';
import { relativeDayLabel } from '../utils/date';
import type { TransactionItem } from '../types/models';

interface TransactionGroupListProps {
  groups: TransactionGroup[];
  onEdit?: (transaction: TransactionItem) => void;
  onRemove?: (transaction: TransactionItem) => void;
}

export function TransactionGroupList({ groups, onEdit, onRemove }: TransactionGroupListProps) {
  const theme = useTheme();
  const { formatMoney } = useAppState();
  const rowRefs = useRef<Map<string, Swipeable>>(new Map());

  if (groups.length === 0) {
    return (
      <Text style={[styles.empty, { color: theme.textMuted }]}>
        No transactions yet. Use Quick Add to record one.
      </Text>
    );
  }
  return (
    <View>
      {groups.map((g) => (
        <View key={g.dayKey} style={styles.group}>
          <View style={styles.groupHeader}>
            <Text style={[styles.groupLabel, { color: theme.textMuted }]}>
              {relativeDayLabel(g.date)}
            </Text>
            <Text style={[styles.groupTotal, { color: theme.textMuted }]}>
              {formatMoney(g.total, { compact: true })}
            </Text>
          </View>
          <View
            style={[
              styles.groupCard,
              { backgroundColor: theme.surface, borderColor: theme.border }
            ]}
          >
            {g.transactions.map((t, idx) => {
              const value =
                t.type === 'expense'
                  ? `-${formatMoney(netExpenseAmount(t), { compact: true })}`
                  : `+${formatMoney(t.amount, { compact: true })}`;

              const rowBody = (
                <>
                  <View style={[styles.dot, { backgroundColor: colorForCategory(t.category) }]} />
                  <View style={styles.txnBody}>
                    <Text style={[styles.txnName, { color: theme.text }]}>{t.name}</Text>
                    <Text style={[styles.txnCategory, { color: theme.textMuted }]}>
                      {t.category}
                      {t.note ? ` · ${t.note}` : ''}
                    </Text>
                  </View>
                  <Text
                    style={[
                      styles.txnAmount,
                      { color: t.type === 'income' ? theme.positive : theme.text }
                    ]}
                  >
                    {value}
                  </Text>
                </>
              );

              const row = onEdit ? (
                <Pressable
                  onPress={() => onEdit(t)}
                  style={({ pressed }) => [
                    styles.txnRow,
                    idx > 0 && {
                      borderTopWidth: StyleSheet.hairlineWidth,
                      borderTopColor: theme.border
                    },
                    pressed && { opacity: 0.7 }
                  ]}
                >
                  {rowBody}
                </Pressable>
              ) : (
                <View
                  style={[
                    styles.txnRow,
                    idx > 0 && {
                      borderTopWidth: StyleSheet.hairlineWidth,
                      borderTopColor: theme.border
                    }
                  ]}
                >
                  {rowBody}
                </View>
              );

              if (!onRemove) return <View key={t.id}>{row}</View>;

              return (
                <Swipeable
                  key={t.id}
                  ref={(el) => {
                    if (el) rowRefs.current.set(t.id, el);
                    else rowRefs.current.delete(t.id);
                  }}
                  friction={2}
                  overshootRight={false}
                  renderRightActions={() => (
                    <RectButton
                      style={[styles.deleteAction, { backgroundColor: theme.danger }]}
                      onPress={() => onRemove(t)}
                    >
                      <Text style={[styles.deleteLabel, { color: theme.textInverse }]}>Delete</Text>
                    </RectButton>
                  )}
                  onSwipeableWillOpen={() => {
                    rowRefs.current.forEach((sw, id) => {
                      if (id !== t.id) sw.close();
                    });
                  }}
                >
                  {row}
                </Swipeable>
              );
            })}
          </View>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  empty: { fontSize: 13, paddingVertical: SPACING.lg, textAlign: 'center' },
  group: { marginBottom: SPACING.md },
  groupHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.xs,
    marginBottom: SPACING.xs
  },
  groupLabel: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase'
  },
  groupTotal: { fontSize: 12, fontWeight: '600' },
  groupCard: { borderRadius: RADIUS.md, borderWidth: StyleSheet.hairlineWidth, overflow: 'hidden' },
  txnRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    backgroundColor: 'transparent'
  },
  dot: { width: 10, height: 10, borderRadius: 5, marginRight: SPACING.sm },
  txnBody: { flex: 1 },
  txnName: { fontSize: 14, fontWeight: '600' },
  txnCategory: { fontSize: 11, marginTop: 1 },
  txnAmount: { fontSize: 14, fontWeight: '700' },
  deleteAction: {
    justifyContent: 'center',
    alignItems: 'center',
    width: 76,
    alignSelf: 'stretch',
    minHeight: 48
  },
  deleteLabel: { fontSize: 13, fontWeight: '700' }
});
