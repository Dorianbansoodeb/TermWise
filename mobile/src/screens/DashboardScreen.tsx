import React, { useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { ScrollView } from 'react-native-gesture-handler';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../theme/useTheme';
import { useAppState } from '../state/AppState';
import { RADIUS, SPACING } from '../theme/tokens';
import { contentBottomPaddingForTabs } from '../navigation/constants';
import {
  computeSpendingBreakdown,
  evaluateTotalPace,
  evaluateVariablePace,
  groupTransactionsByDay,
  monthContext,
  totalIncomeThisMonth
} from '../utils/financeCalculator';
import { Card } from '../components/Card';
import { PillBadge } from '../components/PillBadge';
import { PlanVsRealityBar } from '../components/PlanVsRealityBar';
import { SpendTrendChart } from '../components/SpendTrendChart';
import { SpendTrendRangePicker } from '../components/SpendTrendRangePicker';
import { TransactionGroupList } from '../components/TransactionGroupList';
import { buildChartSeries } from '../utils/chartCalculator';

export function DashboardScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const {
    transactions,
    budgetItems,
    settingsForMonth,
    availableToBudget,
    savingsTarget,
    chartMode,
    variableChartRange,
    setChartMode,
    setVariableChartRange,
    referenceDate,
    appUserSettings,
    removeTransaction,
    formatMoney
  } = useAppState();

  const ctx = monthContext(referenceDate);
  const totalIncome = totalIncomeThisMonth(transactions, referenceDate);

  const variablePace = evaluateVariablePace({
    budgetItems,
    transactions,
    currentDayOfMonth: ctx.currentDayOfMonth,
    daysInMonth: ctx.daysInMonth,
    referenceDate,
    warningThresholdPercent: appUserSettings.budgetWarningThresholdPercent
  });
  const totalPace = evaluateTotalPace({
    transactions,
    budgetItems,
    availableToBudget,
    savingsTarget,
    currentDayOfMonth: ctx.currentDayOfMonth,
    daysInMonth: ctx.daysInMonth,
    referenceDate
  });

  const breakdown = useMemo(
    () =>
      computeSpendingBreakdown({
        transactions,
        availableToBudget,
        referenceDate
      }),
    [transactions, availableToBudget, referenceDate]
  );

  const series = useMemo(
    () =>
      buildChartSeries({
        mode: chartMode,
        range: variableChartRange,
        now: referenceDate,
        transactions,
        budgetItems,
        settings: settingsForMonth,
        availableToBudget
      }),
    [
      chartMode,
      variableChartRange,
      referenceDate,
      transactions,
      budgetItems,
      settingsForMonth,
      availableToBudget
    ]
  );

  const recentGroups = useMemo(
    () => groupTransactionsByDay(transactions).slice(0, 4),
    [transactions]
  );

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingBottom: contentBottomPaddingForTabs(insets.bottom) }
        ]}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.headerRow}>
          <View>
            <Text style={[styles.greeting, { color: theme.textMuted }]}>This month</Text>
            <Text style={[styles.income, { color: theme.text }]}>
              {formatMoney(totalIncome)}
            </Text>
            <Text style={[styles.subtle, { color: theme.textMuted }]}>
              Available to Budget {formatMoney(availableToBudget)}
            </Text>
          </View>
          <PillBadge
            tone={
              variablePace.status === 'onTrack'
                ? 'positive'
                : variablePace.status === 'watch'
                  ? 'warning'
                  : 'danger'
            }
            label={
              chartMode === 'variable'
                ? variablePace.status === 'onTrack'
                  ? 'On Track'
                  : variablePace.status === 'watch'
                    ? 'Watch'
                    : 'Over Budget Risk'
                : totalPace.status === 'onTrack'
                  ? 'On Track'
                  : totalPace.status === 'nearLimit'
                    ? 'Near Limit'
                    : 'Over Budget'
            }
          />
        </View>

        <Card>
          <View style={styles.cardHeader}>
            <View style={{ flex: 1 }}>
              <Text style={[styles.cardTitle, { color: theme.text }]}>
                {chartMode === 'variable' ? 'Variable Spending Trend' : 'Total Spending Trend'}
              </Text>
              <Text style={[styles.cardHelper, { color: theme.textMuted }]} numberOfLines={2}>
                {chartMode === 'variable'
                  ? 'Flexible spending over selected period.'
                  : 'All expenses, projected against your monthly budget.'}
              </Text>
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Switch between variable and total spending trend"
              onPress={() => setChartMode(chartMode === 'variable' ? 'total' : 'variable')}
              style={({ pressed }) => [
                styles.swap,
                {
                  borderColor: theme.border,
                  backgroundColor: theme.surfaceMuted,
                  opacity: pressed ? 0.7 : 1
                }
              ]}
            >
              <View style={styles.swapArrows}>
                <Text style={[styles.swapArrowChar, styles.swapArrowTop, { color: theme.text }]}>
                  →
                </Text>
                <Text style={[styles.swapArrowChar, styles.swapArrowBottom, { color: theme.text }]}>
                  ←
                </Text>
              </View>
            </Pressable>
          </View>

          <SpendTrendChart series={series} />

          {chartMode === 'variable' && (
            <View style={{ marginTop: SPACING.md }}>
              <SpendTrendRangePicker
                value={variableChartRange}
                onChange={setVariableChartRange}
              />
            </View>
          )}

          <Text style={[styles.statusMessage, { color: theme.textMuted }]}>
            {chartMode === 'variable'
              ? variablePace.status === 'overBudgetRisk'
                ? `Projected to spend ${formatMoney(variablePace.projectedMonthEndSpend, { compact: true })} on flexible categories — over your ${formatMoney(variablePace.variableBudget, { compact: true })} limit.`
                : variablePace.status === 'watch'
                  ? 'Pace is close to your variable limit — watch coffee + eating out.'
                  : 'Variable spending is within pace.'
              : totalPace.status === 'overBudget'
                ? `Projected to exceed your monthly budget by ${formatMoney(totalPace.projectedOverAvailableByAmount, { compact: true })} across all expenses.`
                : totalPace.status === 'nearLimit'
                  ? `Projected to use money reserved for savings by ${formatMoney(totalPace.projectedOverBudgetByAmount, { compact: true })}.`
                  : 'Projected spending is within your savings-protected limit.'}
          </Text>
        </Card>

        <PlanVsRealityBar breakdown={breakdown} />

        <View>
          <Text style={[styles.sectionTitle, { color: theme.text }]}>Recent Transactions</Text>
          <Text style={[styles.sectionHint, { color: theme.textMuted }]}>
            Swipe left on a row to delete. Undo is available for 5 seconds.
          </Text>
          <TransactionGroupList
            groups={recentGroups}
            onRemove={(txn) => removeTransaction(txn.id, { withUndo: true })}
          />
        </View>
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
    gap: SPACING.lg
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start'
  },
  greeting: {
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0.4,
    textTransform: 'uppercase'
  },
  income: {
    fontSize: 30,
    fontWeight: '800',
    marginTop: 2
  },
  subtle: {
    fontSize: 12,
    marginTop: 4
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.md,
    gap: SPACING.sm
  },
  cardTitle: {
    fontSize: 15,
    fontWeight: '700'
  },
  cardHelper: {
    fontSize: 11,
    marginTop: 2
  },
  swap: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs + 2,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth,
    minWidth: 44,
    alignItems: 'center',
    justifyContent: 'center'
  },
  swapArrows: {
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center'
  },
  swapArrowChar: {
    fontSize: 11,
    lineHeight: 12,
    fontWeight: '800',
    includeFontPadding: false,
    textAlign: 'center'
  },
  swapArrowTop: {
    marginBottom: -2
  },
  swapArrowBottom: {
    marginTop: -2
  },
  statusMessage: {
    fontSize: 12,
    marginTop: SPACING.md,
    lineHeight: 16
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '700',
    marginBottom: 4
  },
  sectionHint: {
    fontSize: 12,
    marginBottom: SPACING.sm,
    lineHeight: 16
  }
});
