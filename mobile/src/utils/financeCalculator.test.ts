import { describe, expect, it } from 'vitest';
import type { BudgetItem, TransactionItem } from '../types/models';
import {
  actualPaidForBill,
  actualSpentForCategory,
  budgetDifference,
  budgetPercentUsed,
  filterTransactions,
  findFixedBillForCategory,
  fixedBillStatus,
  profileExpenseBreakdownRows,
  profileMonthSummaries,
  recurringBillsForMonth,
  totalBudgeted,
  unallocatedRow,
  usableBudgetAfterSavings,
  variableCategoryProgress,
  variableRiskStatus
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
      mk('3', 'Long-term Savings', 100, 'savings')
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

// --- Fixed bill status ---

describe('fixedBillStatus', () => {
  const ref = new Date('2026-05-15T12:00:00.000Z');

  it('returns paid when actual meets or exceeds planned', () => {
    expect(fixedBillStatus(900, 900, 1, ref)).toBe('paid');
    expect(fixedBillStatus(900, 1000, 1, ref)).toBe('paid');
  });

  it('returns partial when some but not all of planned is paid', () => {
    expect(fixedBillStatus(900, 400, 1, ref)).toBe('partial');
  });

  it('returns overdue when unpaid and due day is before the reference day', () => {
    expect(fixedBillStatus(900, 0, 1, ref)).toBe('overdue');
    expect(fixedBillStatus(900, 0, 14, ref)).toBe('overdue');
  });

  it('returns upcoming when unpaid and due day is on or after the reference day', () => {
    expect(fixedBillStatus(900, 0, 15, ref)).toBe('upcoming');
    expect(fixedBillStatus(900, 0, 28, ref)).toBe('upcoming');
  });

  it('returns upcoming when unpaid and no due day is set', () => {
    expect(fixedBillStatus(900, 0, undefined, ref)).toBe('upcoming');
  });
});

// --- Recurring Bill edits ---

const mkFixed = (
  id: string,
  category: string,
  planned: number,
  extras: Partial<BudgetItem> = {}
): BudgetItem => ({
  id,
  category,
  planned,
  budgetType: 'fixed',
  frequency: 'monthly',
  ...extras
});

const mkBillExpense = (
  id: string,
  billId: string | undefined,
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
  billId,
  source: billId ? 'markAsPaid' : undefined,
  undoable: false
});

describe('recurring bill edits (via updateBudgetItem patch shape)', () => {
  it('raising planned amount flips a previously-paid bill to partial', () => {
    const bill = mkFixed('rent', 'Rent', 900, { dueDay: 1 });
    const txns: TransactionItem[] = [
      mkBillExpense('p1', 'rent', 'Rent', 900, '2026-05-01T09:00:00Z')
    ];
    const before = recurringBillsForMonth([bill], txns, REF).find((b) => b.id === 'rent')!;
    expect(before.status).toBe('paid');
    expect(before.actualPaid).toBe(900);

    // Simulate AppState.updateBudgetItem('rent', { planned: 1200 })
    const patched: BudgetItem = { ...bill, planned: 1200 };
    const after = recurringBillsForMonth([patched], txns, REF).find((b) => b.id === 'rent')!;
    expect(after.plannedAmount).toBe(1200);
    expect(after.actualPaid).toBe(900);
    expect(after.status).toBe('partial');
  });

  it('lowering planned amount can flip a partial bill to paid', () => {
    const bill = mkFixed('phone', 'Phone', 80, { dueDay: 15 });
    const txns: TransactionItem[] = [
      mkBillExpense('p1', 'phone', 'Phone', 60, '2026-05-10T09:00:00Z')
    ];
    const before = recurringBillsForMonth([bill], txns, REF).find((b) => b.id === 'phone')!;
    expect(before.status).toBe('partial');

    const patched: BudgetItem = { ...bill, planned: 60 };
    const after = recurringBillsForMonth([patched], txns, REF).find((b) => b.id === 'phone')!;
    expect(after.status).toBe('paid');
    expect(after.plannedAmount).toBe(60);
  });

  it('renaming a bill preserves attribution of payments linked by billId', () => {
    const bill = mkFixed('phone', 'Phone', 80, { dueDay: 15 });
    const txns: TransactionItem[] = [
      mkBillExpense('p1', 'phone', 'Phone', 60, '2026-05-10T09:00:00Z')
    ];
    // Edit: rename "Phone" → "Mobile Plan"
    const renamed: BudgetItem = { ...bill, category: 'Mobile Plan' };
    expect(actualPaidForBill(renamed, txns, REF)).toBe(60);
    const rolled = recurringBillsForMonth([renamed], txns, REF).find((b) => b.id === 'phone')!;
    expect(rolled.category).toBe('Mobile Plan');
    expect(rolled.actualPaid).toBe(60);
  });

  it('changing due day or frequency is surfaced by recurringBillsForMonth', () => {
    const bill = mkFixed('rent', 'Rent', 900, { dueDay: 1 });
    const patched: BudgetItem = { ...bill, dueDay: 15, frequency: 'biweekly' };
    const rolled = recurringBillsForMonth([patched], [], REF).find((b) => b.id === 'rent')!;
    expect(rolled.dueDay).toBe(15);
    expect(rolled.frequency).toBe('biweekly');
    expect(rolled.status).toBe('upcoming');
  });

  it('clearing due day (set to undefined) is preserved', () => {
    const bill = mkFixed('rent', 'Rent', 900, { dueDay: 1 });
    const patched: BudgetItem = { ...bill, dueDay: undefined };
    const rolled = recurringBillsForMonth([patched], [], REF).find((b) => b.id === 'rent')!;
    expect(rolled.dueDay).toBeUndefined();
  });
});

// --- Quick Add: bill attribution ---

describe('findFixedBillForCategory', () => {
  const budgetItems: BudgetItem[] = [
    mkFixed('rent', 'Rent', 900, { dueDay: 1 }),
    mkFixed('phone', 'Phone', 55, { dueDay: 15 }),
    mkFixed('tuition', 'Tuition Savings', 250, { dueDay: 28 }),
    mkVar('groc', 'Groceries', 280),
    mkVar('coffee', 'Coffee', 40)
  ];

  it('matches an exact fixed-bill category name', () => {
    expect(findFixedBillForCategory('Rent', budgetItems)?.id).toBe('rent');
    expect(findFixedBillForCategory('Phone', budgetItems)?.id).toBe('phone');
  });

  it('matches case-insensitively', () => {
    expect(findFixedBillForCategory('rent', budgetItems)?.id).toBe('rent');
    expect(findFixedBillForCategory('PHONE', budgetItems)?.id).toBe('phone');
  });

  it('matches even when punctuation differs ("Tuition/Savings" preset vs "Tuition Savings" bill)', () => {
    expect(findFixedBillForCategory('Tuition/Savings', budgetItems)?.id).toBe('tuition');
  });

  it('returns undefined for variable / unknown categories', () => {
    expect(findFixedBillForCategory('Groceries', budgetItems)).toBeUndefined();
    expect(findFixedBillForCategory('Coffee', budgetItems)).toBeUndefined();
    expect(findFixedBillForCategory('Mystery', budgetItems)).toBeUndefined();
    expect(findFixedBillForCategory('', budgetItems)).toBeUndefined();
  });
});

describe('profileMonthSummaries', () => {
  it('returns count months oldest-first with shared planned from current budget', () => {
    const ref = new Date(2026, 4, 15, 12, 0, 0, 0);
    const items = [mk('1', 'Rent', 100, 'fixed')];
    const txns = [mkExpense('a', 'Rent', 40, new Date(2026, 3, 10, 12, 0, 0).toISOString())];
    const s = profileMonthSummaries(txns, items, ref, 3);
    expect(s).toHaveLength(3);
    expect(s.map((x) => x.monthKey)).toEqual(['2026-03', '2026-04', '2026-05']);
    expect(s[1].actual).toBe(40);
    expect(s[0].actual).toBe(0);
    expect(s[2].actual).toBe(0);
    expect(s.every((x) => x.planned === 100)).toBe(true);
    expect(s[1].saved).toBe(60);
  });
});

describe('budgetPercentUsed', () => {
  it('handles zero planned', () => {
    expect(budgetPercentUsed(0, 0)).toBe(0);
    expect(budgetPercentUsed(50, 0)).toBe(100);
  });

  it('is actual / planned × 100', () => {
    expect(budgetPercentUsed(50, 100)).toBe(50);
  });
});

describe('profileExpenseBreakdownRows', () => {
  it('allocates expected by budget mix and scales actual with month ratio', () => {
    const items = [mk('a', 'Rent', 60, 'fixed'), mk('b', 'Groceries', 40, 'variable')];
    const rows = profileExpenseBreakdownRows(items, 100, 50);
    expect(rows).toHaveLength(2);
    const rent = rows.find((r) => r.category === 'Rent')!;
    const groc = rows.find((r) => r.category === 'Groceries')!;
    expect(rent.expected).toBeCloseTo(60);
    expect(groc.expected).toBeCloseTo(40);
    expect(rent.actual).toBeCloseTo(30);
    expect(groc.actual).toBeCloseTo(20);
    expect(rows.reduce((sum, r) => sum + r.expected, 0)).toBeCloseTo(100);
    expect(rows.reduce((sum, r) => sum + r.actual, 0)).toBeCloseTo(50);
  });

  it('skips savings budget rows', () => {
    const items = [mk('a', 'Rent', 100, 'fixed'), mk('s', 'Save', 200, 'savings')];
    const rows = profileExpenseBreakdownRows(items, 100, 80);
    expect(rows).toHaveLength(1);
    expect(rows[0].category).toBe('Rent');
  });
});

describe('variableRiskStatus', () => {
  const limit = 1000;

  it('defaults to 90% on-track threshold', () => {
    expect(variableRiskStatus(899, limit)).toBe('onTrack');
    expect(variableRiskStatus(901, limit)).toBe('watch');
    expect(variableRiskStatus(1001, limit)).toBe('overBudgetRisk');
  });

  it('honors a custom warning threshold percent', () => {
    expect(variableRiskStatus(749, limit, 75)).toBe('onTrack');
    expect(variableRiskStatus(751, limit, 75)).toBe('watch');
    expect(variableRiskStatus(1000, limit, 100)).toBe('onTrack');
    expect(variableRiskStatus(1001, limit, 100)).toBe('overBudgetRisk');
  });

  it('returns onTrack when budget limit is zero', () => {
    expect(variableRiskStatus(500, 0, 90)).toBe('onTrack');
  });
});
