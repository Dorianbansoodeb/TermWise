import React, { useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { ScrollView } from 'react-native-gesture-handler';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import {
  filterTransactions,
  groupTransactionsByDay,
  type TransactionFilter
} from '../utils/financeCalculator';
import { TransactionGroupList } from '../components/TransactionGroupList';

const FILTERS: { value: TransactionFilter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'expense', label: 'Expenses' },
  { value: 'income', label: 'Income' }
];

export function TransactionsScreen() {
  const theme = useTheme();
  const { transactions, removeTransaction } = useAppState();
  const [filter, setFilter] = useState<TransactionFilter>('all');

  const groups = useMemo(
    () => groupTransactionsByDay(filterTransactions(transactions, filter)),
    [transactions, filter]
  );

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={[styles.title, { color: theme.text }]}>Transactions</Text>
        <Text style={[styles.subtitle, { color: theme.textMuted }]}>
          Swipe left on a row to delete. Undo is available for 5 seconds.
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
        <TransactionGroupList
          groups={groups}
          onRemove={(txn) => removeTransaction(txn.id, { withUndo: true })}
        />
      </ScrollView>
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
  }
});
