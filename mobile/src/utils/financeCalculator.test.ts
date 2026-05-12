import { describe, expect, it } from 'vitest';
import type { BudgetItem } from '../types/models';
import {
  remainingAfterPlan,
  totalBudgeted,
  unallocatedRow
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
  it('sums fixed + variable only; excludes savings target dollars', () => {
    const items: BudgetItem[] = [
      mk('1', 'Rent', 900, 'fixed'),
      mk('2', 'Groceries', 280, 'variable'),
      mk('3', 'Emergency Fund', 100, 'savings')
    ];
    expect(totalBudgeted(items)).toBe(1180);
  });

  it('matches user example: recurring + variable without savings in total', () => {
    const items: BudgetItem[] = [
      mk('a', 'Bills', 1005, 'fixed'),
      mk('b', 'Variable', 902, 'variable')
    ];
    expect(totalBudgeted(items)).toBe(1907);
  });
});

describe('remainingAfterPlan', () => {
  it('is availableToBudget - totalBudgetedPlanned - savingsTarget', () => {
    expect(remainingAfterPlan(2300, 1907, 345)).toBe(48);
  });

  it('is negative when over-committed', () => {
    expect(remainingAfterPlan(2000, 1907, 345)).toBe(-252);
  });
});

describe('unallocatedRow', () => {
  it('shows Unallocated Budget when remainingAfterPlan >= 0', () => {
    const row = unallocatedRow(2300, 1907, 345);
    expect(row.label).toBe('Unallocated Budget');
    expect(row.value).toBe(48);
    expect(row.isOver).toBe(false);
  });

  it('shows Over Budget By when remainingAfterPlan < 0', () => {
    const row = unallocatedRow(2000, 1907, 345);
    expect(row.label).toBe('Over Budget By');
    expect(row.value).toBe(252);
    expect(row.isOver).toBe(true);
  });

  it('does not fold savings target into totalBudgeted argument', () => {
    const planned = 1907;
    const savings = 345;
    const row = unallocatedRow(2300, planned, savings);
    expect(planned + savings + row.value).toBe(2300);
  });
});
