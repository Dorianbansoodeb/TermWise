import type { BudgetItem, SpendingCategoryColor } from '../types/models';

// Single source of truth for category → color mapping. Mirrors
// `TermWise/CategoryPalette.swift`. Substring + case-insensitive match so
// "Groceries", "Weekly groceries", and "groceries" all resolve to the same swatch.

const HEX: Record<SpendingCategoryColor, string> = {
  indigo: '#6366f1',
  green: '#22c55e',
  orange: '#f97316',
  pink: '#ec4899',
  teal: '#14b8a6',
  purple: '#a855f7',
  gray: '#94a3b8',
  blue: '#3b82f6'
};

export function colorTokenForCategory(category: string): SpendingCategoryColor {
  const value = category.toLowerCase();
  if (value.includes('rent')) return 'indigo';
  if (value.includes('grocer')) return 'green';
  if (value.includes('transport')) return 'orange';
  if (value.includes('eat') || value.includes('coffee')) return 'pink';
  if (value.includes('tuition') || value.includes('saving')) return 'teal';
  if (value.includes('phone')) return 'purple';
  if (value.includes('other')) return 'gray';
  return 'blue';
}

export function colorForCategory(category: string): string {
  return HEX[colorTokenForCategory(category)];
}

/// Variable Spending Trend excludes these category keywords (rent, phone bill,
/// tuition/savings, subscriptions, loan payments). Anything not matched is
/// treated as variable for pace purposes (parity with `VariableSpendingPace`).
const FIXED_KEYWORDS = ['rent', 'phone', 'tuition', 'saving', 'subscription', 'loan', 'insurance'];

export function isVariableCategoryName(name: string): boolean {
  const value = name.toLowerCase();
  return !FIXED_KEYWORDS.some((kw) => value.includes(kw));
}

/// Decide whether a transaction's free-form category should count toward
/// variable spending pace given the user's current budget items. Falls back to
/// "treat as variable" when the category isn't represented in budgets so a
/// generic "Other" purchase still moves the variable line.
export function isVariableTransactionCategory(
  transactionCategory: string,
  budgetItems: BudgetItem[]
): boolean {
  const value = transactionCategory.toLowerCase();
  const match = budgetItems.find((item) => {
    const cat = item.category.toLowerCase();
    return cat === value || cat.includes(value) || value.includes(cat);
  });
  if (match) return match.budgetType === 'variable';
  return isVariableCategoryName(transactionCategory);
}

/// Preset categories surfaced in Quick Add. Order matches iOS.
export const PRESET_EXPENSE_CATEGORIES: string[] = [
  'Groceries',
  'Eating Out',
  'Coffee',
  'Transportation',
  'Fun',
  'Shopping',
  'Rent',
  'Phone',
  'Subscriptions',
  'Other'
];

export const PRESET_INCOME_CATEGORIES: string[] = [
  'Paycheck',
  'Co-op Pay',
  'Side Gig',
  'Gift',
  'Other'
];
