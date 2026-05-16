import type { BudgetItem } from '../types/models';

export type BudgetPieSliceKind = 'fixed' | 'variable';

export interface BudgetPlannedPieSlice {
  id: string;
  label: string;
  value: number;
  kind: BudgetPieSliceKind;
}

const HOUSING_RE = /rent|housing|residence|lease|dorm|apartment/i;
const FOOD_RE = /grocery|groceries|food|dining|eat|coffee|meal|restaurant/i;

/** Stable id for the aggregated small-variable wedge in charts. */
export const OTHER_VARIABLE_SLICE_ID = '__other_variable__';

const OTHER_VARIABLE_LABEL = 'Other variable';

/// Variable slices at or above this share of **total** planned (fixed + variable) stay separate.
/// Also never smaller than `SMALL_VARIABLE_ABS_USD` so tiny one-off style lines clump together.
const SMALL_VARIABLE_FRAC_OF_TOTAL = 0.05;
const SMALL_VARIABLE_ABS_USD = 40;

/// Fixed bills stay one wedge each. Variable lines with a small planned amount (including
/// typical one-time fee buckets) merge into **Other variable** unless the line is large enough
/// to clear a combined absolute + %-of-total threshold. Wedges are **largest to smallest** for
/// both the chart and legend.
export function budgetPlannedPieSlices(budgetItems: BudgetItem[]): BudgetPlannedPieSlice[] {
  const fixed = budgetItems
    .filter((b) => b.budgetType === 'fixed' && b.planned > 0)
    .map((b) => ({
      id: b.id,
      label: b.category.trim() || 'Recurring',
      value: Math.max(0, b.planned),
      kind: 'fixed' as const
    }));
  const variableRaw = budgetItems
    .filter((b) => b.budgetType === 'variable' && b.planned > 0)
    .map((b) => ({
      id: b.id,
      label: b.category.trim() || 'Variable',
      value: Math.max(0, b.planned),
      kind: 'variable' as const
    }));

  const fixedSum = fixed.reduce((a, s) => a + s.value, 0);
  const variableSum = variableRaw.reduce((a, s) => a + s.value, 0);
  const grandTotal = fixedSum + variableSum;
  if (grandTotal <= 0) return [];

  const threshold = Math.max(
    SMALL_VARIABLE_ABS_USD,
    SMALL_VARIABLE_FRAC_OF_TOTAL * grandTotal
  );

  const largeVariable: BudgetPlannedPieSlice[] = [];
  let otherVariable = 0;
  for (const row of variableRaw) {
    if (row.value >= threshold) largeVariable.push(row);
    else otherVariable += row.value;
  }

  const out: BudgetPlannedPieSlice[] = [...fixed, ...largeVariable];
  if (otherVariable > 0) {
    out.push({
      id: OTHER_VARIABLE_SLICE_ID,
      label: OTHER_VARIABLE_LABEL,
      value: otherVariable,
      kind: 'variable'
    });
  }
  out.sort((a, b) => b.value - a.value);
  return out;
}

export function totalPlannedPieAmount(slices: BudgetPlannedPieSlice[]): number {
  return slices.reduce((s, x) => s + x.value, 0);
}

/** Planned housing (fixed lines matching keywords) as a share of Available to Budget. */
export function housingPlannedPercentOfAvailable(
  budgetItems: BudgetItem[],
  availableToBudget: number
): number | null {
  if (!Number.isFinite(availableToBudget) || availableToBudget <= 0) return null;
  const housing = budgetItems.filter(
    (b) => b.budgetType === 'fixed' && HOUSING_RE.test(b.category) && b.planned > 0
  );
  if (housing.length === 0) return null;
  const sum = housing.reduce((a, b) => a + Math.max(0, b.planned), 0);
  return (sum / availableToBudget) * 100;
}

/** Sum of variable category limits that look food-related (rough heuristic). */
export function foodLikeVariablePlannedTotal(budgetItems: BudgetItem[]): number {
  return budgetItems
    .filter((b) => b.budgetType === 'variable' && FOOD_RE.test(b.category))
    .reduce((a, b) => a + Math.max(0, b.planned), 0);
}

/**
 * Short educational lines — not financial advice; rough public-student-guide
 * ballparks for UI context (housing % of spend; food $ planning band).
 */
export function studentBudgetBenchmarkLines(
  budgetItems: BudgetItem[],
  availableToBudget: number
): string[] {
  const lines: string[] = [];
  const housingPct = housingPlannedPercentOfAvailable(budgetItems, availableToBudget);
  if (housingPct != null) {
    const rounded = Math.round(housingPct * 10) / 10;
    lines.push(
      `Student-oriented guides often suggest keeping housing near 30–40% of what you can spend each month when you can. Your budgeted housing is about ${rounded}% of Available to Budget.`
    );
  } else {
    lines.push(
      'Many student guides aim for housing around 30–40% of monthly spend when it is realistic. Add a rent or housing line (or set Available to Budget) to see your share here.'
    );
  }

  const foodPlanned = foodLikeVariablePlannedTotal(budgetItems);
  if (foodPlanned > 0) {
    const roundedFood = Math.round(foodPlanned);
    lines.push(
      `Food-style variable categories in your plan total about $${roundedFood}/mo. As a very rough planning band (like a daily calorie guideline, not a rule), some campus budgeting handouts use about $300–450/mo per person for groceries and meals in Canada — adjust for city, diet, and meal plan.`
    );
  } else {
    lines.push(
      'For flexible food spending, some rough planning bands (Canada, very approximate) sit around $300–450/mo per person — useful for ballparking, not a universal target. Add categories such as Groceries or Eating out to compare your plan.'
    );
  }
  return lines;
}
