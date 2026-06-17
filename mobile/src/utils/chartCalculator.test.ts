import { describe, expect, it } from 'vitest';
import { buildDemoState } from '../state/demoData';
import { buildChartSeries } from './chartCalculator';
import { prepareStateForReferenceMonth } from '../state/storage';

describe('buildChartSeries', () => {
  const now = new Date(2026, 5, 17, 12, 0, 0);

  it('plots variable spend for the current month', () => {
    const state = buildDemoState(now);
    const series = buildChartSeries({
      mode: 'variable',
      range: 'currentMonth',
      now,
      transactions: state.transactions,
      budgetItems: state.budgetItems,
      settings: state.monthlySettingsByMonth['2026-06'],
      availableToBudget: 2300
    });

    expect(series.todayIdx).toBe(17);
    expect(Math.max(...series.actualCumulative)).toBeGreaterThan(0);
    expect(series.limitLines).toHaveLength(1);
    expect(series.limitLines[0]?.role).toBe('variableLimit');
  });

  it('hides zero-value total limit lines', () => {
    const state = buildDemoState(now);
    const series = buildChartSeries({
      mode: 'total',
      range: 'currentMonth',
      now,
      transactions: state.transactions,
      budgetItems: state.budgetItems,
      settings: { monthKey: '2026-06', availableToBudget: 0, desiredSavingsRate: 0.15 },
      availableToBudget: 0
    });

    expect(series.limitLines).toHaveLength(0);
  });
});

describe('prepareStateForReferenceMonth', () => {
  it('seeds demo transactions when persisted data is from a prior month', () => {
    const march = new Date(2026, 2, 17, 12, 0, 0);
    const june = new Date(2026, 5, 17, 12, 0, 0);
    const stale = buildDemoState(march);

    const hydrated = prepareStateForReferenceMonth(stale, june);
    const hasJuneExpense = hydrated.transactions.some(
      (t) => t.type === 'expense' && t.date.startsWith('2026-06')
    );

    expect(hydrated.transactions.length).toBeGreaterThan(stale.transactions.length);
    expect(hasJuneExpense).toBe(true);
    expect(hydrated.monthlySettingsByMonth['2026-06']).toBeDefined();
  });
});
