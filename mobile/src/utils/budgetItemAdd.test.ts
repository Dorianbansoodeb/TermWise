import { describe, expect, it } from 'vitest';
import type { BudgetItem } from '../types/models';
import {
  buildRecurringBudgetItemDraft,
  buildVariableBudgetItemDraft,
  validateRecurringBillAdd,
  validateVariableCategoryAdd
} from './budgetItemAdd';
import { recurringBillsForMonth, totalBudgeted, variableCategoryProgress } from './financeCalculator';

const refDate = new Date('2026-05-14T12:00:00');

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

describe('budgetItemAdd flow', () => {
  const base: BudgetItem[] = [
    mk('1', 'Rent', 900, 'fixed'),
    mk('2', 'Groceries', 280, 'variable')
  ];

  it('adding a recurring bill increases Total Budgeted', () => {
    const before = totalBudgeted(base);
    const draft = buildRecurringBudgetItemDraft({
      category: 'Water',
      planned: 55,
      frequency: 'monthly',
      dueDay: 10
    });
    const after = totalBudgeted([...base, { ...draft, id: 'new-fixed' }]);
    expect(after).toBe(before + 55);
  });

  it('adding a variable spending category increases Total Budgeted', () => {
    const before = totalBudgeted(base);
    const draft = buildVariableBudgetItemDraft({ category: 'Coffee', planned: 40 });
    const after = totalBudgeted([...base, { ...draft, id: 'new-var' }]);
    expect(after).toBe(before + 40);
  });

  it('new fixed bill starts Unpaid when there are no matching transactions', () => {
    const draft = buildRecurringBudgetItemDraft({
      category: 'Water',
      planned: 55,
      frequency: 'monthly',
      dueDay: 10
    });
    const bills = recurringBillsForMonth([...base, { ...draft, id: 'new-fixed' }], [], refDate);
    expect(bills.find((b) => b.id === 'new-fixed')?.status).toBe('unpaid');
  });

  it('new variable category starts with actual = 0', () => {
    const draft = buildVariableBudgetItemDraft({ category: 'Coffee', planned: 40 });
    const item: BudgetItem = { ...draft, id: 'new-var' };
    const progress = variableCategoryProgress(item, [], refDate);
    expect(progress.actual).toBe(0);
  });

  it('rejects an empty recurring bill name', () => {
    const r = validateRecurringBillAdd({
      categoryTrimmed: '',
      planned: 50,
      frequency: 'monthly',
      dueDayStr: '5',
      dueDateStr: ''
    });
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.message).toMatch(/bill name/i);
  });

  it('rejects recurring amount <= 0', () => {
    const r = validateRecurringBillAdd({
      categoryTrimmed: 'Power',
      planned: 0,
      frequency: 'monthly',
      dueDayStr: '5',
      dueDateStr: ''
    });
    expect(r.ok).toBe(false);
  });

  it('rejects an empty variable category name', () => {
    const r = validateVariableCategoryAdd({ categoryTrimmed: '', limit: 25 });
    expect(r.ok).toBe(false);
  });

  it('rejects variable limit <= 0', () => {
    const r = validateVariableCategoryAdd({ categoryTrimmed: 'Fun', limit: -1 });
    expect(r.ok).toBe(false);
  });
});

function removeBudgetItemFromList(items: BudgetItem[], id: string): BudgetItem[] {
  return items.filter((item) => item.id !== id);
}

describe('budget item removal', () => {
  const base: BudgetItem[] = [
    mk('1', 'Rent', 900, 'fixed'),
    mk('2', 'Groceries', 280, 'variable')
  ];

  it('removing a recurring bill decreases Total Budgeted', () => {
    const before = totalBudgeted(base);
    const after = totalBudgeted(removeBudgetItemFromList(base, '1'));
    expect(after).toBe(before - 900);
    expect(after).toBe(280);
  });

  it('removing a variable category decreases Total Budgeted', () => {
    const before = totalBudgeted(base);
    const after = totalBudgeted(removeBudgetItemFromList(base, '2'));
    expect(after).toBe(before - 280);
    expect(after).toBe(900);
  });

  it('removing an unknown id leaves the list unchanged', () => {
    const next = removeBudgetItemFromList(base, 'missing');
    expect(next).toEqual(base);
    expect(totalBudgeted(next)).toBe(totalBudgeted(base));
  });
});
