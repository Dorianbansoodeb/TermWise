import { describe, expect, it } from 'vitest';
import type { BudgetItem } from '../types/models';
import {
  budgetDifference,
  totalBudgeted,
  unallocatedRow,
  usableBudgetAfterSavings
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
