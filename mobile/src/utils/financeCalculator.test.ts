import { describe, expect, it } from 'vitest';
import type { BudgetItem, TransactionItem } from '../types/models';
import {
  actualSpentForCategory,
  budgetDifference,
  totalBudgeted,
  unallocatedRow,
  usableBudgetAfterSavings,
  variableCategoryProgress
} from './financeCalculator';

const mk = (
  id: string,
  category: string,
  planned: number,
  budgetType: BudgetItem['budgetType']
): BudgetItem => ({
  id,
  category,
  planned,
  budgetType,
  frequency: 'none'
});

describe('totalBudgeted', () => {
  it('sums fixed + variable only; excludes savings target items', () => {
    const items: BudgetItem[] = [
      mk('1', 'Rent', 900, 'fixed'),
      mk('2', 'Groceries', 280, 'variable'),
      mk('3', 'Emergency Fund', 100, 'savings')
    ];
    expect(totalBudgeted(items)).toBe(1180);
  });

  it('matches the user example (recurring + variable only)', () => {
    const items: BudgetItem[] = [
      mk('a', 'Bills', 1205, 'fixed'),
      mk('b', 'Variable', 595, 'variable')
    ];
    expect(totalBudgeted(items)).toBe(1800);
  });
});

describe('budgetDifference', () => {
  it('is availableToBudget - totalBudgeted (no savings)', () => {
    expect(budgetDifference(1800, 1800)).toBe(0);
    expect(budgetDifference(2300, 1907)).toBe(393);
    expect(budgetDifference(2000, 1907)).toBe(93);
  });

  it('goes negative only when planned spending exceeds available', () => {
    expect(budgetDifference(1500, 1907)).toBe(-407);
  });
});

describe('unallocatedRow', () => {
  it('shows Unallocated Budget when availableToBudget >= totalBudgeted', () => {
    const row = unallocatedRow(2300, 1907);
    expect(row.label).toBe('Unallocated Budget');
    expect(row.value).toBe(393);
    expect(row.isOver).toBe(false);
  });

  it('shows Over Budget By only when planned spending exceeds available', () => {
    const row = unallocatedRow(1500, 1907);
    expect(row.label).toBe('Over Budget By');
    expect(row.value).toBe(407);
    expect(row.isOver).toBe(true);
  });

  it('matches the user example: $1,800 / $1,800 ⇒ $0 unallocated', () => {
    const row = unallocatedRow(1800, 1800);
    expect(row.label).toBe('Unallocated Budget');
    expect(row.value).toBe(0);
    expect(row.isOver).toBe(false);
  });

  it('is unaffected by Savings Target — savings is not an argument', () => {
    // unallocatedRow's signature does not accept savings; we prove the
    // value is identical regardless of any caller-side savings goal.
    const planned = 1800;
    const available = 1800;
    const savings = 270;
    const row = unallocatedRow(available, planned);
    expect(row.label).toBe('Unallocated Budget');
    expect(row.value).toBe(0);
    // The savings goal sits next to the envelope, never folded in:
    expect(usableBudgetAfterSavings(available, savings)).toBe(1530);
  });

  it('a $187.50 savings goal does NOT make a balanced budget go over', () => {
    // Regression for the user's reported bug:
    //   Total Budgeted = $1,907 / Savings Target = $187.50 / available $1,800
    //   should be Over Budget By $107 (purely from planned vs available),
    //   not Over Budget By $844.50 (which incorrectly subtracted savings).
    const row = unallocatedRow(1800, 1907);
    expect(row.label).toBe('Over Budget By');
    expect(row.value).toBe(107);
  });
});

describe('usableBudgetAfterSavings (charts-only spend limit)', () => {
  it('is availableToBudget − savingsTarget, floored at 0', () => {
    expect(usableBudgetAfterSavings(1800, 270)).toBe(1530);
    expect(usableBudgetAfterSavings(1800, 0)).toBe(1800);
    expect(usableBudgetAfterSavings(1800, 5000)).toBe(0);
  });
});

// --- Variable Spending per-category progress ---

const REF = new Date('2026-05-15T12:00:00.000Z');

const mkVar = (id: string, category: string, planned: number): BudgetItem =>
  mk(id, category, planned, 'variable');

const mkExpense = (
  id: string,
  category: string,
  amount: number,
  isoDate: string
): TransactionItem => ({
  id,
  amount,
  name: category,
  category,
  note: '',
  date: isoDate,
  createdAt: isoDate,
  type: 'expense',
  savedApplied: 0,
  undoable: false
});

describe('actualSpentForCategory', () => {
  it('sums case-insensitive matches inside the current month only', () => {
    const txns: TransactionItem[] = [
      mkExpense('a', 'Groceries', 42, '2026-05-02T10:00:00Z'),
      mkExpense('b', 'groceries', 90.5, '2026-05-10T10:00:00Z'),
      // different month — must be excluded:
      mkExpense('c', 'Groceries', 100, '2026-04-30T10:00:00Z'),
      // different category — must be excluded:
      mkExpense('d', 'Eating Out', 25, '2026-05-11T10:00:00Z')
    ];
    expect(actualSpentForCategory('Groceries', txns, REF)).toBe(132.5);
  });

  it('returns 0 for an empty category name', () => {
    expect(actualSpentForCategory('  ', [], REF)).toBe(0);
  });
});

describe('variableCategoryProgress', () => {
  it('under limit: percentUsed = actual / limit, status onTrack, remaining = limit − actual', () => {
    // Groceries example from spec: actual=$132.50 / limit=$280 → 47%
    const item = mkVar('g', 'Groceries', 280);
    const txns: TransactionItem[] = [
      mkExpense('a', 'Groceries', 42, '2026-05-02T10:00:00Z'),
      mkExpense('b', 'Groceries', 90.5, '2026-05-10T10:00:00Z')
    ];
    const p = variableCategoryProgress(item, txns, REF);
    expect(p.planned).toBe(280);
    expect(p.actual).toBe(132.5);
    expect(Math.round(p.percentUsed * 100)).toBe(47);
    expect(p.displayProgress).toBeCloseTo(132.5 / 280, 5);
    expect(p.remaining).toBe(147.5);
    expect(p.over).toBe(0);
    expect(p.status).toBe('onTrack');
  });

  it('over limit: status overBudget, displayProgress capped at 1, over = actual − limit', () => {
    // Coffee example from spec: limit=$40, actual=$55 → over by $15, bar pinned to 100%
    const item = mkVar('c', 'Coffee', 40);
    const txns: TransactionItem[] = [
      mkExpense('a', 'Coffee', 30, '2026-05-04T10:00:00Z'),
      mkExpense('b', 'Coffee', 25, '2026-05-12T10:00:00Z')
    ];
    const p = variableCategoryProgress(item, txns, REF);
    expect(p.planned).toBe(40);
    expect(p.actual).toBe(55);
    expect(p.percentUsed).toBeCloseTo(55 / 40, 5);
    expect(p.displayProgress).toBe(1);
    expect(p.remaining).toBe(0);
    expect(p.over).toBe(15);
    expect(p.status).toBe('overBudget');
  });

  it('exactly at the limit: onTrack with 0 remaining and 0 over', () => {
    const item = mkVar('f', 'Fun', 100);
    const txns: TransactionItem[] = [mkExpense('a', 'Fun', 100, '2026-05-07T10:00:00Z')];
    const p = variableCategoryProgress(item, txns, REF);
    expect(p.status).toBe('onTrack');
    expect(p.percentUsed).toBe(1);
    expect(p.displayProgress).toBe(1);
    expect(p.remaining).toBe(0);
    expect(p.over).toBe(0);
  });

  it('zero monthly limit: percentUsed/displayProgress are 0 (no division by zero)', () => {
    const item = mkVar('s', 'Shopping', 0);
    const txns: TransactionItem[] = [
      mkExpense('a', 'Shopping', 25, '2026-05-09T10:00:00Z')
    ];
    const p = variableCategoryProgress(item, txns, REF);
    expect(p.percentUsed).toBe(0);
    expect(p.displayProgress).toBe(0);
    // Any spend against a $0 limit still counts as over budget by the spend amount.
    expect(p.over).toBe(25);
    expect(p.status).toBe('overBudget');
  });

  it('editing the monthly limit flips status without re-spending: $55 actual vs new $80 limit → onTrack', () => {
    // Simulates the AppState.updateBudgetItem({ planned: 80 }) flow: re-call the
    // helper with the patched item and the same transactions.
    const txns: TransactionItem[] = [
      mkExpense('a', 'Coffee', 30, '2026-05-04T10:00:00Z'),
      mkExpense('b', 'Coffee', 25, '2026-05-12T10:00:00Z')
    ];
    const before = variableCategoryProgress(mkVar('c', 'Coffee', 40), txns, REF);
    const after = variableCategoryProgress(mkVar('c', 'Coffee', 80), txns, REF);
    expect(before.status).toBe('overBudget');
    expect(after.status).toBe('onTrack');
    expect(after.remaining).toBe(25);
    expect(after.over).toBe(0);
    expect(after.displayProgress).toBeCloseTo(55 / 80, 5);
  });
});
