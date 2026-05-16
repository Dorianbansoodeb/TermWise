import { describe, expect, it } from 'vitest';
import type { BudgetItem } from '../types/models';
import {
  budgetPlannedPieSlices,
  foodLikeVariablePlannedTotal,
  housingPlannedPercentOfAvailable,
  studentBudgetBenchmarkLines,
  totalPlannedPieAmount
} from './budgetPlanVisualization';

const fixed = (id: string, category: string, planned: number): BudgetItem => ({
  id,
  category,
  planned,
  budgetType: 'fixed',
  frequency: 'monthly'
});

const variable = (id: string, category: string, planned: number): BudgetItem => ({
  id,
  category,
  planned,
  budgetType: 'variable',
  frequency: 'none'
});

describe('budgetPlannedPieSlices', () => {
  it('keeps fixed and large variable wedges; clumps small variable into Other variable', () => {
    const items: BudgetItem[] = [
      fixed('1', 'Rent', 900),
      fixed('2', 'Zero', 0),
      variable('3', 'Groceries', 280),
      variable('4', 'Fun', 50)
    ];
    const s = budgetPlannedPieSlices(items);
    expect(s.map((x) => x.label)).toEqual(['Rent', 'Groceries', 'Other variable']);
    const other = s.find((x) => x.label === 'Other variable');
    expect(other?.value).toBe(50);
    expect(totalPlannedPieAmount(s)).toBe(1230);
  });

  it('keeps variable lines that clear the small-slice threshold', () => {
    const items: BudgetItem[] = [
      fixed('1', 'Rent', 900),
      variable('2', 'Groceries', 280),
      variable('3', 'Car', 800)
    ];
    const s = budgetPlannedPieSlices(items);
    expect(s.map((x) => x.label)).toEqual(['Rent', 'Car', 'Groceries']);
    expect(s.some((x) => x.label === 'Other variable')).toBe(false);
  });

  it('merges multiple small variable lines into one Other variable wedge', () => {
    const items: BudgetItem[] = [
      fixed('1', 'Rent', 1000),
      variable('2', 'Fees', 30),
      variable('3', 'Misc', 20)
    ];
    const s = budgetPlannedPieSlices(items);
    expect(s.map((x) => x.label)).toEqual(['Rent', 'Other variable']);
    expect(s.find((x) => x.label === 'Other variable')?.value).toBe(50);
  });

  it('sorts all wedges largest to smallest (fixed and variable interleaved)', () => {
    const items: BudgetItem[] = [
      fixed('a', 'Phone', 55),
      fixed('b', 'Rent', 900),
      variable('c', 'Groceries', 400)
    ];
    const s = budgetPlannedPieSlices(items);
    expect(s.map((x) => x.label)).toEqual(['Rent', 'Groceries', 'Phone']);
    expect(s.map((x) => x.value)).toEqual([900, 400, 55]);
  });

  it('returns empty when nothing planned', () => {
    expect(budgetPlannedPieSlices([])).toEqual([]);
  });
});

describe('housingPlannedPercentOfAvailable', () => {
  it('sums housing-like fixed lines over available', () => {
    const items = [fixed('r', 'Rent', 600), variable('g', 'Groceries', 200)];
    expect(housingPlannedPercentOfAvailable(items, 2000)).toBe(30);
  });

  it('returns null when envelope is zero', () => {
    expect(housingPlannedPercentOfAvailable([fixed('r', 'Rent', 600)], 0)).toBeNull();
  });
});

describe('foodLikeVariablePlannedTotal', () => {
  it('sums variable lines matching food heuristics', () => {
    const items = [
      variable('a', 'Groceries', 200),
      variable('b', 'Eating Out', 80),
      variable('c', 'Transport', 40)
    ];
    expect(foodLikeVariablePlannedTotal(items)).toBe(280);
  });
});

describe('studentBudgetBenchmarkLines', () => {
  it('returns two paragraphs', () => {
    const lines = studentBudgetBenchmarkLines(
      [fixed('r', 'Rent', 500), variable('g', 'Groceries', 200)],
      2000
    );
    expect(lines).toHaveLength(2);
    expect(lines[0]).toContain('25');
    expect(lines[1]).toContain('200');
  });
});
