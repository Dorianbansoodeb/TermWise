// TermWise pure finance facade. All exports are deterministic and free of
// React/AsyncStorage so they can be unit-tested in isolation. Mirrors the
// SwiftUI `FinanceCalculator`, `FinanceBudgetAllocation`, `VariableSpendingPace`,
// and `TotalSpendingPace` enums.

import type {
  BudgetItem,
  FixedBillStatus,
  MonthlySettings,
  RecurringBill,
  TransactionItem
} from '../types/models';
import { isSameMonth, parseDate, startOfMonth } from './date';
import { isVariableTransactionCategory } from './categories';

const DEFAULT_SAVINGS_RATE = 0.15;

// MARK: - Net expense helper

/// Net expense for a transaction (parity with `BudgetSpendCalculator.netExpenseAmount`).
/// Money already pulled from savings (savedApplied) reduces the spend that
/// counts against this month's budget.
export function netExpenseAmount(txn: TransactionItem): number {
  if (txn.type !== 'expense') return 0;
  return Math.max(0, txn.amount - Math.max(0, txn.savedApplied));
}

// MARK: - 1. Income vs budget

export function totalIncomeThisMonth(transactions: TransactionItem[], referenceDate: Date): number {
  return transactions
    .filter((t) => t.type === 'income' && isSameMonth(parseDate(t.date), referenceDate))
    .reduce((acc, t) => acc + Math.max(0, t.amount), 0);
}

export function totalExpensesThisMonth(transactions: TransactionItem[], referenceDate: Date): number {
  return transactions
    .filter((t) => t.type === 'expense' && isSameMonth(parseDate(t.date), referenceDate))
    .reduce((acc, t) => acc + netExpenseAmount(t), 0);
}

/// Money the user has chosen to budget this month. Uses the explicit override
/// when present; otherwise defaults to recorded income (parity with iOS
/// `FinanceBudgetAllocation.calculateAvailableToBudget`).
export function availableToBudgetForMonth(
  transactions: TransactionItem[],
  settings: MonthlySettings | undefined,
  referenceDate: Date
): number {
  if (settings && typeof settings.availableToBudget === 'number') {
    return Math.max(0, settings.availableToBudget);
  }
  return totalIncomeThisMonth(transactions, referenceDate);
}

/// `max(0, totalIncome − availableToBudget)`. Income parked outside the envelope.
/// Always non-negative — when the user is budgeting more than they've earned,
/// the UI surfaces the inverse via `budgetingOverIncomeAmount` instead.
export function reserveNotBudgeted(totalIncome: number, availableToBudget: number): number {
  return Math.max(0, totalIncome - availableToBudget);
}

/// `max(0, availableToBudget − totalIncome)`. The amount by which the user
/// has chosen to budget more than they've actually earned this month. Drives
/// the "Budgeting Over Income" row that replaces "Reserve / Not Budgeted"
/// when the envelope exceeds Total Income.
export function budgetingOverIncomeAmount(
  totalIncome: number,
  availableToBudget: number
): number {
  return Math.max(0, availableToBudget - totalIncome);
}

// MARK: - 2. Budget difference / allocation

/// Planned spending only: **recurring / fixed bills + variable category limits**.
/// Does **not** include the Savings Target dollar amount — savings are a
/// comfort goal, not a planned expense, so they have no effect on
/// `budgetDifference` / Unallocated Budget / Over Budget By.
export function totalBudgeted(budgetItems: BudgetItem[]): number {
  const recurring = budgetItems
    .filter((b) => b.budgetType === 'fixed')
    .reduce((acc, b) => acc + Math.max(0, b.planned), 0);
  const variable = budgetItems
    .filter((b) => b.budgetType === 'variable')
    .reduce((acc, b) => acc + Math.max(0, b.planned), 0);
  return recurring + variable;
}

/// `availableToBudget − totalBudgeted`. Positive = unallocated headroom;
/// negative = over-allocated. Savings Target is intentionally **not** part of
/// this calculation — see `usableBudgetAfterSavings` for the savings-aware
/// spend-limit used by charts.
export function budgetDifference(availableToBudget: number, totalBudgetedPlanned: number): number {
  return availableToBudget - totalBudgetedPlanned;
}

export interface UnallocatedRow {
  label: 'Unallocated Budget' | 'Over Budget By';
  value: number;
  isOver: boolean;
}

/// Envelope unallocated / over-budget row driven purely by
/// `budgetDifference`. Savings Target does not influence this row.
export function unallocatedRow(
  availableToBudget: number,
  totalBudgetedPlanned: number
): UnallocatedRow {
  const diff = budgetDifference(availableToBudget, totalBudgetedPlanned);
  if (diff >= 0) {
    return { label: 'Unallocated Budget', value: diff, isOver: false };
  }
  return { label: 'Over Budget By', value: Math.abs(diff), isOver: true };
}

/// Savings Target = explicit override OR `desiredSavingsRate × availableToBudget`.
export function resolvedSavingsTarget(
  availableToBudget: number,
  settings: MonthlySettings | undefined
): number {
  if (settings && typeof settings.customSavingsTarget === 'number') {
    return Math.max(0, settings.customSavingsTarget);
  }
  const rate = settings?.desiredSavingsRate ?? DEFAULT_SAVINGS_RATE;
  return Math.max(0, availableToBudget * Math.max(0, rate));
}

/// `max(0, availableToBudget − savingsTarget)`. Used as the Total Spending
/// Trend "Spend Limit" green line.
export function usableBudgetAfterSavings(availableToBudget: number, savingsTarget: number): number {
  return Math.max(0, Math.max(0, availableToBudget) - Math.max(0, savingsTarget));
}

/// Inline warning shown beneath the Available to Budget editor whenever the
/// chosen envelope exceeds Total Income. Returns `null` when there is no
/// warning to surface.
///
/// Examples:
///   warning(1250, 2300) → "You are budgeting $1,050 more than your recorded income."
///   warning(1250, 1250) → null
///   warning(1250,  900) → null
export function availableToBudgetWarning(
  totalIncome: number,
  availableToBudget: number
): string | null {
  const over = budgetingOverIncomeAmount(totalIncome, availableToBudget);
  if (over <= 0) return null;
  const formatted = formatWarningCurrency(over);
  return `You are budgeting ${formatted} more than your recorded income.`;
}

function formatWarningCurrency(value: number): string {
  // Keep this inline so financeCalculator stays free of `format.ts`'s Intl
  // wrapper. The shape mirrors `formatCurrency({ compact: true })`.
  if (!Number.isFinite(value)) return '$0';
  const rounded = Math.round(value);
  return `$${rounded.toLocaleString('en-US')}`;
}

// MARK: - 3. Recurring bill status

/// Net actual paid this month for a fixed bill. Matches transactions either
/// by `billId` (Mark-as-Paid) or by category name (manual entries).
export function actualPaidForBill(
  bill: BudgetItem,
  transactions: TransactionItem[],
  referenceDate: Date
): number {
  return transactions
    .filter((t) => {
      if (t.type !== 'expense') return false;
      if (!isSameMonth(parseDate(t.date), referenceDate)) return false;
      if (t.billId && t.billId === bill.id) return true;
      return t.category.toLowerCase() === bill.category.toLowerCase();
    })
    .reduce((acc, t) => acc + netExpenseAmount(t), 0);
}

export function fixedBillStatus(planned: number, actual: number): FixedBillStatus {
  if (actual <= 0) return 'unpaid';
  if (actual < planned) return 'partial';
  return 'paid';
}

export function recurringBillsForMonth(
  budgetItems: BudgetItem[],
  transactions: TransactionItem[],
  referenceDate: Date
): RecurringBill[] {
  return budgetItems
    .filter((b) => b.budgetType === 'fixed')
    .map((b) => {
      const actual = actualPaidForBill(b, transactions, referenceDate);
      return {
        id: b.id,
        category: b.category,
        plannedAmount: b.planned,
        dueDay: b.dueDay,
        frequency: b.frequency,
        actualPaid: actual,
        status: fixedBillStatus(b.planned, actual)
      };
    });
}

// MARK: - 4a. Per-variable-category progress

export type VariableCategoryStatus = 'onTrack' | 'overBudget';

export interface VariableCategoryProgress {
  /** Monthly limit for the variable category (from `BudgetItem.planned`). */
  planned: number;
  /** Net expense spent against this category this calendar month. */
  actual: number;
  /** Raw `actual / planned` (uncapped). `0` when there is no limit yet. */
  percentUsed: number;
  /** `min(1, percentUsed)` — what the thin bar should render. */
  displayProgress: number;
  /** `max(0, planned − actual)` — remaining headroom when on track. */
  remaining: number;
  /** `max(0, actual − planned)` — overspend amount when over budget. */
  over: number;
  /** Card status badge: `onTrack` when `actual ≤ planned`, else `overBudget`. */
  status: VariableCategoryStatus;
}

/// Sum of net-expense transactions whose category matches `category`
/// (case-insensitive exact match) inside `referenceDate`'s month. Used to
/// drive a single Variable Spending card without leaking spend from
/// neighbouring categories.
export function actualSpentForCategory(
  category: string,
  transactions: TransactionItem[],
  referenceDate: Date
): number {
  const target = category.trim().toLowerCase();
  if (target === '') return 0;
  return transactions
    .filter((t) => {
      if (t.type !== 'expense') return false;
      if (!isSameMonth(parseDate(t.date), referenceDate)) return false;
      return t.category.trim().toLowerCase() === target;
    })
    .reduce((acc, t) => acc + netExpenseAmount(t), 0);
}

/// Per-category roll-up driving the Variable Spending card UI: planned,
/// actual, capped progress, remaining/over, and an `onTrack`/`overBudget`
/// status badge. Spend is taken from `actualSpentForCategory` so flexible
/// categories don't accidentally count Mark-as-Paid fixed-bill expenses.
export function variableCategoryProgress(
  item: BudgetItem,
  transactions: TransactionItem[],
  referenceDate: Date
): VariableCategoryProgress {
  const planned = Math.max(0, item.planned);
  const actual = actualSpentForCategory(item.category, transactions, referenceDate);
  const percentUsed = planned > 0 ? actual / planned : 0;
  const displayProgress = planned > 0 ? Math.min(1, percentUsed) : 0;
  const remaining = Math.max(0, planned - actual);
  const over = Math.max(0, actual - planned);
  const status: VariableCategoryStatus = actual > planned ? 'overBudget' : 'onTrack';
  return { planned, actual, percentUsed, displayProgress, remaining, over, status };
}

// MARK: - 4. Variable spending pace

export type VariableRiskStatus = 'onTrack' | 'watch' | 'overBudgetRisk';

export interface VariablePaceResult {
  variableBudget: number;
  variableSpent: number;
  expectedSpentByToday: number;
  projectedMonthEndSpend: number;
  status: VariableRiskStatus;
}

export function variableBudget(budgetItems: BudgetItem[]): number {
  return budgetItems
    .filter((b) => b.budgetType === 'variable')
    .reduce((acc, b) => acc + Math.max(0, b.planned), 0);
}

export function variableTransactionsThisMonth(
  transactions: TransactionItem[],
  budgetItems: BudgetItem[],
  referenceDate: Date
): TransactionItem[] {
  return transactions.filter(
    (t) =>
      t.type === 'expense' &&
      isSameMonth(parseDate(t.date), referenceDate) &&
      isVariableTransactionCategory(t.category, budgetItems)
  );
}

export function variableSpent(
  transactions: TransactionItem[],
  budgetItems: BudgetItem[],
  referenceDate: Date
): number {
  return variableTransactionsThisMonth(transactions, budgetItems, referenceDate).reduce(
    (acc, t) => acc + netExpenseAmount(t),
    0
  );
}

/// Risk thresholds match SwiftUI: <=90% → onTrack, <=100% → watch, >100% → over.
export function variableRiskStatus(
  projectedSpend: number,
  variableBudgetLimit: number
): VariableRiskStatus {
  if (variableBudgetLimit <= 0) return 'onTrack';
  if (projectedSpend <= variableBudgetLimit * 0.9) return 'onTrack';
  if (projectedSpend <= variableBudgetLimit) return 'watch';
  return 'overBudgetRisk';
}

export function evaluateVariablePace(args: {
  budgetItems: BudgetItem[];
  transactions: TransactionItem[];
  currentDayOfMonth: number;
  daysInMonth: number;
  referenceDate: Date;
}): VariablePaceResult {
  const budget = variableBudget(args.budgetItems);
  const spent = variableSpent(args.transactions, args.budgetItems, args.referenceDate);
  const safeDaysInMonth = Math.max(1, args.daysInMonth);
  const safeDaysElapsed = Math.max(1, Math.min(args.currentDayOfMonth, args.daysInMonth));
  const expected = budget * (safeDaysElapsed / safeDaysInMonth);
  const projected = (spent / safeDaysElapsed) * safeDaysInMonth;
  return {
    variableBudget: budget,
    variableSpent: spent,
    expectedSpentByToday: expected,
    projectedMonthEndSpend: projected,
    status: variableRiskStatus(projected, budget)
  };
}

// MARK: - 5. Total spending pace

export type TotalRiskStatus = 'onTrack' | 'nearLimit' | 'overBudget';

export interface TotalPaceResult {
  availableToBudget: number;
  savingsTarget: number;
  spendLimit: number;
  totalSpent: number;
  variableSpentSoFar: number;
  projectedVariableMonthEndSpend: number;
  expectedFixedBillsThisMonth: number;
  unpaidFixedBillsRemaining: number;
  projectedMonthEndSpend: number;
  expectedSpentByToday: number;
  status: TotalRiskStatus;
  overBudgetByAmount: number;
  projectedOverBudgetByAmount: number;
  projectedOverAvailableByAmount: number;
}

/// Σ `planned` over all fixed/recurring budget items expected for the month.
export function expectedFixedBillsThisMonth(budgetItems: BudgetItem[]): number {
  return budgetItems
    .filter((b) => b.budgetType === 'fixed')
    .reduce((acc, b) => acc + Math.max(0, b.planned), 0);
}

/// Σ `max(0, planned − actualPaidThisMonth)` over the fixed bills. Paying a
/// fixed bill clamps its remaining to 0 so the projected month-end stays flat
/// (parity with `TotalSpendingPace.evaluate`).
export function unpaidFixedBillsRemaining(
  budgetItems: BudgetItem[],
  transactions: TransactionItem[],
  referenceDate: Date
): number {
  return budgetItems
    .filter((b) => b.budgetType === 'fixed')
    .reduce((acc, b) => {
      const actual = actualPaidForBill(b, transactions, referenceDate);
      return acc + Math.max(0, b.planned - actual);
    }, 0);
}

export function evaluateTotalPace(args: {
  transactions: TransactionItem[];
  budgetItems: BudgetItem[];
  availableToBudget: number;
  savingsTarget: number;
  currentDayOfMonth: number;
  daysInMonth: number;
  referenceDate: Date;
}): TotalPaceResult {
  const spent = totalExpensesThisMonth(args.transactions, args.referenceDate);
  const varSpent = variableSpent(args.transactions, args.budgetItems, args.referenceDate);
  const expectedFixed = expectedFixedBillsThisMonth(args.budgetItems);
  const unpaidFixed = unpaidFixedBillsRemaining(args.budgetItems, args.transactions, args.referenceDate);
  return evaluateTotalPaceWithTotals({
    totalSpentThisPeriod: spent,
    availableToBudget: args.availableToBudget,
    savingsTarget: args.savingsTarget,
    variableSpentSoFar: varSpent,
    expectedFixedBillsThisPeriod: expectedFixed,
    unpaidFixedBillsRemainingThisPeriod: unpaidFixed,
    currentDayOfPeriod: args.currentDayOfMonth,
    periodLengthDays: args.daysInMonth
  });
}

export function evaluateTotalPaceWithTotals(args: {
  totalSpentThisPeriod: number;
  availableToBudget: number;
  savingsTarget: number;
  variableSpentSoFar: number;
  expectedFixedBillsThisPeriod: number;
  unpaidFixedBillsRemainingThisPeriod: number;
  currentDayOfPeriod: number;
  periodLengthDays: number;
}): TotalPaceResult {
  const safeAvailable = Math.max(0, args.availableToBudget);
  const safeSavings = Math.max(0, args.savingsTarget);
  const spendLimit = Math.max(0, safeAvailable - safeSavings);
  const safeVariableSpent = Math.max(0, args.variableSpentSoFar);
  const safeExpectedFixed = Math.max(0, args.expectedFixedBillsThisPeriod);
  const safeUnpaidFixed = Math.max(0, args.unpaidFixedBillsRemainingThisPeriod);
  const spent = Math.max(0, args.totalSpentThisPeriod);
  const safeDaysInMonth = Math.max(1, args.periodLengthDays);
  const safeDaysElapsed = Math.max(1, Math.min(args.currentDayOfPeriod, args.periodLengthDays));
  const daysRemaining = Math.max(0, safeDaysInMonth - safeDaysElapsed);
  const variableDailyRate = safeVariableSpent / safeDaysElapsed;
  const futureVariableProjection = variableDailyRate * daysRemaining;
  const projectedVariableMonthEnd = variableDailyRate * safeDaysInMonth;
  const projected = spent + futureVariableProjection + safeUnpaidFixed;
  const expected = spendLimit * (safeDaysElapsed / safeDaysInMonth);
  const overBy = Math.max(0, spent - spendLimit);
  const projectedOverSpendLimit = Math.max(0, projected - spendLimit);
  const projectedOverAvailable = Math.max(0, projected - safeAvailable);

  let status: TotalRiskStatus;
  if (projected > safeAvailable) status = 'overBudget';
  else if (projected > spendLimit) status = 'nearLimit';
  else status = 'onTrack';

  return {
    availableToBudget: safeAvailable,
    savingsTarget: safeSavings,
    spendLimit,
    totalSpent: spent,
    variableSpentSoFar: safeVariableSpent,
    projectedVariableMonthEndSpend: projectedVariableMonthEnd,
    expectedFixedBillsThisMonth: safeExpectedFixed,
    unpaidFixedBillsRemaining: safeUnpaidFixed,
    projectedMonthEndSpend: projected,
    expectedSpentByToday: expected,
    status,
    overBudgetByAmount: overBy,
    projectedOverBudgetByAmount: projectedOverSpendLimit,
    projectedOverAvailableByAmount: projectedOverAvailable
  };
}

// MARK: - 6. Transaction grouping + filtering

export interface TransactionGroup {
  /// `yyyy-MM-dd` key (sortable).
  dayKey: string;
  date: Date;
  total: number;
  transactions: TransactionItem[];
}

export function groupTransactionsByDay(transactions: TransactionItem[]): TransactionGroup[] {
  const groups = new Map<string, TransactionGroup>();
  for (const txn of transactions) {
    const date = parseDate(txn.date);
    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(
      date.getDate()
    ).padStart(2, '0')}`;
    const existing = groups.get(key);
    if (existing) {
      existing.transactions.push(txn);
      existing.total += txn.type === 'expense' ? netExpenseAmount(txn) : txn.amount;
    } else {
      groups.set(key, {
        dayKey: key,
        date,
        total: txn.type === 'expense' ? netExpenseAmount(txn) : txn.amount,
        transactions: [txn]
      });
    }
  }
  const list = Array.from(groups.values());
  list.sort((a, b) => b.dayKey.localeCompare(a.dayKey));
  for (const g of list) {
    g.transactions.sort(
      (a, b) => parseDate(b.createdAt).getTime() - parseDate(a.createdAt).getTime()
    );
  }
  return list;
}

export type TransactionFilter = 'all' | 'expense' | 'income';

export function filterTransactions(
  transactions: TransactionItem[],
  filter: TransactionFilter
): TransactionItem[] {
  if (filter === 'all') return transactions;
  return transactions.filter((t) => t.type === filter);
}

// MARK: - 7. Plan vs Reality spending breakdown

export interface SpendingBreakdownSegment {
  category: string;
  amount: number;
  fractionOfAvailable: number;
  color: string;
}

export interface SpendingBreakdown {
  segments: SpendingBreakdownSegment[];
  actualTotal: number;
  availableToBudget: number;
  overBudgetByAmount: number;
  isOver: boolean;
}

import { colorForCategory } from './categories';

export function computeSpendingBreakdown(args: {
  transactions: TransactionItem[];
  availableToBudget: number;
  referenceDate: Date;
}): SpendingBreakdown {
  const monthExpenses = args.transactions.filter(
    (t) => t.type === 'expense' && isSameMonth(parseDate(t.date), args.referenceDate)
  );
  const totals = new Map<string, number>();
  let actualTotal = 0;
  for (const txn of monthExpenses) {
    const net = netExpenseAmount(txn);
    actualTotal += net;
    totals.set(txn.category, (totals.get(txn.category) ?? 0) + net);
  }
  const safeAvailable = Math.max(0, args.availableToBudget);
  const segments: SpendingBreakdownSegment[] = Array.from(totals.entries())
    .filter(([, amount]) => amount > 0)
    .map(([category, amount]) => ({
      category,
      amount,
      fractionOfAvailable: safeAvailable > 0 ? amount / safeAvailable : 0,
      color: colorForCategory(category)
    }))
    .sort((a, b) => b.amount - a.amount);
  return {
    segments,
    actualTotal,
    availableToBudget: safeAvailable,
    overBudgetByAmount: Math.max(0, actualTotal - safeAvailable),
    isOver: actualTotal > safeAvailable
  };
}

// MARK: - 8. Tooltip row title contracts (parity with iOS tests)

export const SPENDING_TREND_VARIABLE_TOOLTIP_PAST: readonly string[] = ['Actual', 'Budget Pace'];
export const SPENDING_TREND_VARIABLE_TOOLTIP_FUTURE: readonly string[] = ['Projected', 'Budget Pace'];
export const SPENDING_TREND_TOTAL_TOOLTIP_PAST: readonly string[] = ['Actual'];
export const SPENDING_TREND_TOTAL_TOOLTIP_FUTURE: readonly string[] = [
  'Projected total spending',
  'Remaining fixed bills'
];

// MARK: - 9. Convenience month context

export interface MonthContext {
  /// 1-based day of month for `referenceDate` (today).
  currentDayOfMonth: number;
  daysInMonth: number;
  monthStart: Date;
}

export function monthContext(referenceDate: Date): MonthContext {
  return {
    currentDayOfMonth: referenceDate.getDate(),
    daysInMonth: new Date(referenceDate.getFullYear(), referenceDate.getMonth() + 1, 0).getDate(),
    monthStart: startOfMonth(referenceDate)
  };
}
