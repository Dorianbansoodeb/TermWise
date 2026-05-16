// Pure data prep for the Spending Trend chart. Mirrors the SwiftUI domain
// helpers in `SpendTrendRange.swift`, `SpendTrendRangeMath.swift`, and
// `SpendingSeries.swift`. Returns plain arrays/numbers — the SVG chart
// component consumes these without doing any math of its own.

import type {
  BudgetItem,
  ChartMode,
  ChartRange,
  MonthlySettings,
  TransactionItem
} from '../types/models';
import { addDays, isSameDay, parseDate, startOfDay } from './date';
import {
  evaluateTotalPace,
  evaluateVariablePace,
  netExpenseAmount,
  resolvedSavingsTarget,
  variableBudget,
  type TotalPaceResult,
  type VariablePaceResult
} from './financeCalculator';
import { isVariableTransactionCategory } from './categories';

export const VARIABLE_PICKER_RANGES: readonly ChartRange[] = [
  'sevenDays',
  'thirtyDays',
  'currentMonth'
];

export function rangeShortLabel(range: ChartRange): string {
  switch (range) {
    case 'sevenDays':
      return '7D';
    case 'thirtyDays':
      return '30D';
    case 'currentMonth':
      return 'Month';
  }
}

/// Trailing-window ranges (7D / 30D) hide the month-end projection line
/// because their forecast is unstable — same rule as iOS.
export function isTrailingShortRange(range: ChartRange): boolean {
  return range === 'sevenDays' || range === 'thirtyDays';
}

export function selectedDays(range: ChartRange, daysInCalendarMonth: number): number {
  switch (range) {
    case 'sevenDays':
      return 7;
    case 'thirtyDays':
      return 30;
    case 'currentMonth':
      return Math.max(1, daysInCalendarMonth);
  }
}

export interface ScaledPeriod {
  periodAvailableToBudget: number;
  periodSavingsTarget: number;
  periodSpendLimit: number;
  periodVariableLimit: number;
}

/// Proportional rescale of budget caps for a windowed range. Matches
/// `SpendTrendRangeMath.scaledPeriod` so a 7-day card shows `availableToBudget × 7/30`.
export function scaledPeriod(args: {
  range: ChartRange;
  daysInMonth: number;
  availableToBudget: number;
  savingsTarget: number;
  variableLimitForMonth: number;
}): ScaledPeriod {
  const days = selectedDays(args.range, args.daysInMonth);
  const fraction = days / Math.max(1, args.daysInMonth);
  return {
    periodAvailableToBudget: args.availableToBudget * fraction,
    periodSavingsTarget: args.savingsTarget * fraction,
    periodSpendLimit: Math.max(0, args.availableToBudget - args.savingsTarget) * fraction,
    periodVariableLimit: args.variableLimitForMonth * fraction
  };
}

// MARK: - Window day starts

/// One date per slot from oldest → newest. `currentMonth` enumerates the full
/// calendar month (so future slots are visible); short ranges trail back from
/// `now`.
export function windowDayStarts(args: { range: ChartRange; now: Date }): Date[] {
  const today = startOfDay(args.now);
  if (args.range === 'currentMonth') {
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
    const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
    return Array.from({ length: daysInMonth }, (_, i) => addDays(monthStart, i));
  }
  const days = selectedDays(args.range, 30);
  return Array.from({ length: days }, (_, i) => addDays(today, -(days - 1 - i)));
}

/// 1-based index of today's slot in the window, or `length` if today falls
/// after the window (rare — only via clock skew).
export function effectiveTodaySlot(slots: Date[], now: Date): number {
  for (let i = 0; i < slots.length; i++) {
    const slot = slots[i];
    if (slot && isSameDay(slot, now)) return i + 1;
  }
  return slots.length;
}

// MARK: - Cumulative spend series

function cumulativePerSlot(
  txns: TransactionItem[],
  slots: Date[],
  todayIdx: number
): number[] {
  const slotIndex = new Map<string, number>();
  slots.forEach((d, idx) => {
    slotIndex.set(`${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`, idx);
  });
  const daily = new Array<number>(slots.length).fill(0);
  for (const txn of txns) {
    if (txn.type !== 'expense') continue;
    const d = parseDate(txn.date);
    const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
    const idx = slotIndex.get(key);
    if (idx === undefined) continue;
    daily[idx] = (daily[idx] ?? 0) + netExpenseAmount(txn);
  }
  const cum = new Array<number>(slots.length).fill(0);
  let running = 0;
  const lastIdx = Math.min(todayIdx, slots.length);
  for (let i = 0; i < lastIdx; i++) {
    running += daily[i] ?? 0;
    cum[i] = running;
  }
  // Future slots intentionally repeat the last actual value so the line does
  // not jump down — the chart hides them visually anyway (parity with iOS
  // `SpendingSeries.cumulativeSpendPerDaySlot`).
  for (let i = lastIdx; i < slots.length; i++) {
    cum[i] = running;
  }
  return cum;
}

export function cumulativeVariableSpendPerDaySlot(args: {
  transactions: TransactionItem[];
  budgetItems: BudgetItem[];
  slots: Date[];
  todayIdx: number;
}): number[] {
  const variable = args.transactions.filter(
    (t) =>
      t.type === 'expense' && isVariableTransactionCategory(t.category, args.budgetItems)
  );
  return cumulativePerSlot(variable, args.slots, args.todayIdx);
}

export function cumulativeTotalSpendPerDaySlot(args: {
  transactions: TransactionItem[];
  slots: Date[];
  todayIdx: number;
}): number[] {
  return cumulativePerSlot(args.transactions, args.slots, args.todayIdx);
}

// MARK: - Chart series builder

export interface ChartSeries {
  mode: ChartMode;
  range: ChartRange;
  slots: Date[];
  todayIdx: number;
  /// Cumulative actual spend per slot (blue line). Future slots reuse the
  /// "today" value — render layer should mask everything past `todayIdx`.
  actualCumulative: number[];
  /// Per-slot pace line value (orange "Budget Pace" / dashed "Spend Limit"
  /// pace). Always linear across the window.
  paceCumulative: number[];
  /// Month-end projection scalar to draw the red dashed line from
  /// `actualCumulative[todayIdx-1]` to `(slots.length, projectedEndValue)`.
  projectedEndValue: number;
  /// Whether to draw the red dashed projection line. Hidden for trailing
  /// short ranges in variable mode.
  drawsProjectionLine: boolean;
  /// Static cap lines drawn across the window for context.
  limitLines: ChartLimitLine[];
  /// Pre-computed risk + pace evaluation used by header copy.
  variablePace: VariablePaceResult;
  totalPace: TotalPaceResult;
  scaled: ScaledPeriod;
  /// True when the window currently has zero actual + zero pace data.
  isEmpty: boolean;
}

export interface ChartLimitLine {
  label: string;
  value: number;
  color: string;
  /** dashed when true */
  dashed: boolean;
}

export function buildChartSeries(args: {
  mode: ChartMode;
  range: ChartRange;
  now: Date;
  transactions: TransactionItem[];
  budgetItems: BudgetItem[];
  settings: MonthlySettings | undefined;
  availableToBudget: number;
}): ChartSeries {
  // For Total mode we always pin to `currentMonth` — matches SwiftUI.
  const effectiveRange: ChartRange = args.mode === 'total' ? 'currentMonth' : args.range;
  const slots = windowDayStarts({ range: effectiveRange, now: args.now });
  const todayIdx = effectiveTodaySlot(slots, args.now);
  const daysInMonth = new Date(args.now.getFullYear(), args.now.getMonth() + 1, 0).getDate();

  const variableLimitForMonth = variableBudget(args.budgetItems);
  const savingsTarget = resolvedSavingsTarget(args.availableToBudget, args.settings);
  const scaled = scaledPeriod({
    range: effectiveRange,
    daysInMonth,
    availableToBudget: args.availableToBudget,
    savingsTarget,
    variableLimitForMonth
  });

  const variablePace = evaluateVariablePace({
    budgetItems: args.budgetItems,
    transactions: args.transactions,
    currentDayOfMonth: args.now.getDate(),
    daysInMonth,
    referenceDate: args.now
  });
  const totalPace = evaluateTotalPace({
    transactions: args.transactions,
    budgetItems: args.budgetItems,
    availableToBudget: args.availableToBudget,
    savingsTarget,
    currentDayOfMonth: args.now.getDate(),
    daysInMonth,
    referenceDate: args.now
  });

  let actualCumulative: number[];
  let paceCumulative: number[];
  let projectedEndValue: number;
  let drawsProjectionLine: boolean;
  let limitLines: ChartLimitLine[];

  if (args.mode === 'variable') {
    actualCumulative = cumulativeVariableSpendPerDaySlot({
      transactions: args.transactions,
      budgetItems: args.budgetItems,
      slots,
      todayIdx
    });
    const perSlotLimit = scaled.periodVariableLimit / Math.max(1, slots.length);
    paceCumulative = slots.map((_, i) => perSlotLimit * (i + 1));
    projectedEndValue = variablePace.projectedMonthEndSpend;
    drawsProjectionLine = !isTrailingShortRange(effectiveRange);
    limitLines = [
      {
        label: `Limit ${formatDollars(scaled.periodVariableLimit)}`,
        value: scaled.periodVariableLimit,
        color: '#94a3b8',
        dashed: true
      }
    ];
  } else {
    actualCumulative = cumulativeTotalSpendPerDaySlot({
      transactions: args.transactions,
      slots,
      todayIdx
    });
    const perSlotSpendLimit = scaled.periodSpendLimit / Math.max(1, slots.length);
    paceCumulative = slots.map((_, i) => perSlotSpendLimit * (i + 1));
    projectedEndValue = totalPace.projectedMonthEndSpend;
    drawsProjectionLine = true;
    limitLines = [
      {
        label: `Available ${formatDollars(scaled.periodAvailableToBudget)}`,
        value: scaled.periodAvailableToBudget,
        color: '#94a3b8',
        dashed: true
      },
      {
        label: `Spend Limit ${formatDollars(scaled.periodSpendLimit)}`,
        value: scaled.periodSpendLimit,
        color: '#22c55e',
        dashed: false
      }
    ];
  }

  const isEmpty =
    actualCumulative.every((v) => v === 0) && paceCumulative.every((v) => v === 0);

  return {
    mode: args.mode,
    range: effectiveRange,
    slots,
    todayIdx,
    actualCumulative,
    paceCumulative,
    projectedEndValue,
    drawsProjectionLine,
    limitLines,
    variablePace,
    totalPace,
    scaled,
    isEmpty
  };
}

function formatDollars(value: number): string {
  if (!Number.isFinite(value)) return '$0';
  return `$${Math.round(value).toLocaleString('en-US')}`;
}

// MARK: - Tooltip row builder

export type TooltipKind = 'variable-past' | 'variable-future' | 'total-past' | 'total-future';

export interface TooltipRow {
  label: string;
  value: number;
}

export function tooltipRowsForSlot(args: {
  series: ChartSeries;
  slotIndex: number;
}): { kind: TooltipKind; rows: TooltipRow[]; date: Date } {
  const { series, slotIndex } = args;
  const slot = series.slots[slotIndex] ?? series.slots[series.slots.length - 1];
  const isFuture = slotIndex + 1 > series.todayIdx;
  const actual = series.actualCumulative[slotIndex] ?? 0;
  const pace = series.paceCumulative[slotIndex] ?? 0;

  if (series.mode === 'variable') {
    if (isFuture) {
      const rows: TooltipRow[] = [
        { label: 'Budget Pace', value: pace }
      ];
      if (series.drawsProjectionLine) {
        rows.unshift({
          label: 'Projected',
          value: projectedForSlot(series, slotIndex)
        });
      }
      return { kind: 'variable-future', rows, date: slot ?? series.slots[0]! };
    }
    return {
      kind: 'variable-past',
      rows: [
        { label: 'Actual', value: actual },
        { label: 'Budget Pace', value: pace }
      ],
      date: slot ?? series.slots[0]!
    };
  }

  if (isFuture) {
    const projectedTotal = projectedForSlot(series, slotIndex);
    return {
      kind: 'total-future',
      rows: [
        { label: 'Projected total spending', value: projectedTotal },
        { label: 'Remaining fixed bills', value: series.totalPace.unpaidFixedBillsRemaining }
      ],
      date: slot ?? series.slots[0]!
    };
  }
  return {
    kind: 'total-past',
    rows: [{ label: 'Actual', value: actual }],
    date: slot ?? series.slots[0]!
  };
}

function projectedForSlot(series: ChartSeries, slotIndex: number): number {
  const startIdx = Math.max(0, series.todayIdx - 1);
  const startValue = series.actualCumulative[startIdx] ?? 0;
  const endIdx = series.slots.length - 1;
  if (endIdx <= startIdx) return startValue;
  const t = (slotIndex - startIdx) / (endIdx - startIdx);
  return startValue + Math.max(0, t) * (series.projectedEndValue - startValue);
}
