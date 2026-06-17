import React, { useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { ScrollView } from 'react-native-gesture-handler';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import {
  filterTransactions,
  groupTransactionsByDay,
  type TransactionFilter
} from '../utils/financeCalculator';
import { TransactionGroupList } from '../components/TransactionGroupList';
import { EditTransactionSheet } from '../components/EditTransactionSheet';
import { contentBottomPaddingForTabs } from '../navigation/constants';
import type { TransactionItem } from '../types/models';

const FILTERS: { value: TransactionFilter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'expense', label: 'Expenses' },
  { value: 'income', label: 'Income' }
];

export function TransactionsScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { transactions, removeTransaction, updateTransaction } = useAppState();
  const [filter, setFilter] = useState<TransactionFilter>('all');
  const [editingTransaction, setEditingTransaction] = useState<TransactionItem | null>(null);
  const [categoryFilter, setCategoryFilter] = useState<string | null>(null);

  const categories = useMemo(() => {
    const names = new Set<string>();
    for (const txn of transactions) {
      const name = txn.category.trim();
      if (name) names.add(txn.category);
    }
    return Array.from(names).sort((a, b) => a.localeCompare(b));
  }, [transactions]);

  const groups = useMemo(
    () =>
      groupTransactionsByDay(filterTransactions(transactions, filter, categoryFilter)),
    [transactions, filter, categoryFilter]
  );

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingBottom: contentBottomPaddingForTabs(insets.bottom) }
        ]}
      >
        <Text style={[styles.title, { color: theme.text }]}>Transactions</Text>
        <Text style={[styles.subtitle, { color: theme.textMuted }]}>
          Tap a row to edit. Swipe left to delete. Undo is available for 5 seconds.
        </Text>
        <View style={[styles.filterRow, { backgroundColor: theme.surfaceMuted }]}>
          {FILTERS.map((f) => {
            const selected = f.value === filter;
            return (
              <Pressable
                key={f.value}
                onPress={() => setFilter(f.value)}
                style={[
                  styles.filter,
                  selected && {
                    backgroundColor: theme.surface,
                    borderColor: theme.border
                  }
                ]}
              >
                <Text
                  style={[
                    styles.filterLabel,
                    {
                      color: selected ? theme.text : theme.textMuted,
                      fontWeight: selected ? '700' : '500'
                    }
                  ]}
                >
                  {f.label}
                </Text>
              </Pressable>
            );
          })}
        </View>
        {categories.length > 0 ? (
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.categoryScroll}
          >
            {(['__all__', ...categories] as const).map((value) => {
              const selected =
                value === '__all__' ? categoryFilter === null : categoryFilter === value;
              const label = value === '__all__' ? 'All categories' : value;
              return (
                <Pressable
                  key={value}
                  onPress={() => setCategoryFilter(value === '__all__' ? null : value)}
                  style={[
                    styles.categoryPill,
                    {
                      backgroundColor: selected ? theme.surface : theme.surfaceMuted,
                      borderColor: selected ? theme.border : 'transparent'
                    }
                  ]}
                >
                  <Text
                    style={[
                      styles.categoryPillLabel,
                      {
                        color: selected ? theme.text : theme.textMuted,
                        fontWeight: selected ? '700' : '500'
                      }
                    ]}
                  >
                    {label}
                  </Text>
                </Pressable>
              );
            })}
          </ScrollView>
        ) : null}
        <TransactionGroupList
          groups={groups}
          onEdit={setEditingTransaction}
          onRemove={(txn) => removeTransaction(txn.id, { withUndo: true })}
        />
      </ScrollView>

      <EditTransactionSheet
        visible={editingTransaction !== null}
        transaction={editingTransaction}
        onCancel={() => setEditingTransaction(null)}
        onSave={(patch) => {
          if (editingTransaction) updateTransaction(editingTransaction.id, patch);
          setEditingTransaction(null);
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1
  },
  scroll: {
    padding: SPACING.lg,
    gap: SPACING.md
  },
  title: {
    fontSize: 26,
    fontWeight: '800'
  },
  subtitle: {
    fontSize: 12
  },
  filterRow: {
    flexDirection: 'row',
    padding: 3,
    borderRadius: RADIUS.pill,
    gap: 2
  },
  filter: {
    flex: 1,
    paddingVertical: SPACING.xs + 2,
    borderRadius: RADIUS.pill,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'transparent'
  },
  filterLabel: {
    fontSize: 12
  },
  categoryScroll: {
    gap: SPACING.xs,
    paddingVertical: 2
  },
  categoryPill: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs + 2,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth
  },
  categoryPillLabel: {
    fontSize: 12
  }
});
