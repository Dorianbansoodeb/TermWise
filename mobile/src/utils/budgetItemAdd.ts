import type { BudgetItem, PaymentFrequency } from '../types/models';

export type NewBudgetItemDraft = Omit<BudgetItem, 'id'>;

function parseDueDayField(dueDayStr: string): { ok: true; value?: number } | { ok: false } {
  const t = dueDayStr.trim();
  if (t === '') return { ok: true, value: undefined };
  const n = parseInt(t, 10);
  if (!Number.isFinite(n) || n < 1 || n > 31) return { ok: false };
  return { ok: true, value: n };
}

/** Validates `YYYY-MM-DD` as a real calendar date (local). */
export function parseLocalDateOnly(
  raw: string
): { ok: true; isoDate: string } | { ok: false } {
  const t = raw.trim();
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(t);
  if (!m) return { ok: false };
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  const dt = new Date(y, mo - 1, d);
  if (dt.getFullYear() !== y || dt.getMonth() !== mo - 1 || dt.getDate() !== d) {
    return { ok: false };
  }
  const isoDate = `${y}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  return { ok: true, isoDate };
}

export function validateRecurringBillAdd(input: {
  categoryTrimmed: string;
  planned: number;
  frequency: PaymentFrequency;
  dueDayStr: string;
  dueDateStr: string;
}):
  | { ok: true; dueDay?: number; dueDate?: string }
  | { ok: false; message: string } {
  if (input.categoryTrimmed.length === 0) {
    return { ok: false, message: 'Enter a bill name.' };
  }
  if (!Number.isFinite(input.planned) || input.planned <= 0) {
    return { ok: false, message: 'Monthly amount must be greater than zero.' };
  }

  if (input.frequency === 'monthly') {
    const d = parseDueDayField(input.dueDayStr);
    if (!d.ok || d.value === undefined) {
      return {
        ok: false,
        message: 'Choose a due day between 1 and 31 for a monthly bill.'
      };
    }
    return { ok: true, dueDay: d.value, dueDate: undefined };
  }

  if (input.frequency === 'oneTime') {
    const dateTrim = input.dueDateStr.trim();
    if (dateTrim !== '') {
      const parsed = parseLocalDateOnly(dateTrim);
      if (!parsed.ok) {
        return {
          ok: false,
          message: 'Enter a valid due date using YYYY-MM-DD (for example 2026-05-01).'
        };
      }
      return { ok: true, dueDate: parsed.isoDate, dueDay: undefined };
    }
    const d = parseDueDayField(input.dueDayStr);
    if (!d.ok) {
      return {
        ok: false,
        message: 'Enter a day between 1 and 31, or leave blank if you add a due date instead.'
      };
    }
    return { ok: true, dueDay: d.value, dueDate: undefined };
  }

  const d = parseDueDayField(input.dueDayStr);
  if (!d.ok) {
    return {
      ok: false,
      message: 'Enter a day between 1 and 31, or leave the field blank.'
    };
  }
  return { ok: true, dueDay: d.value, dueDate: undefined };
}

export function validateVariableCategoryAdd(input: {
  categoryTrimmed: string;
  limit: number;
}): { ok: true } | { ok: false; message: string } {
  if (input.categoryTrimmed.length === 0) {
    return { ok: false, message: 'Enter a category name.' };
  }
  if (!Number.isFinite(input.limit) || input.limit <= 0) {
    return { ok: false, message: 'Monthly limit must be greater than zero.' };
  }
  return { ok: true };
}

export function buildRecurringBudgetItemDraft(args: {
  category: string;
  planned: number;
  frequency: PaymentFrequency;
  dueDay?: number;
  dueDate?: string;
  memo?: string;
}): NewBudgetItemDraft {
  const memoTrim = args.memo?.trim();
  const draft: NewBudgetItemDraft = {
    category: args.category.trim(),
    planned: args.planned,
    budgetType: 'fixed',
    frequency: args.frequency,
    dueDay: args.dueDay,
    dueDate: args.dueDate
  };
  if (memoTrim) draft.memo = memoTrim;
  return draft;
}

export function buildVariableBudgetItemDraft(args: {
  category: string;
  planned: number;
}): NewBudgetItemDraft {
  return {
    category: args.category.trim(),
    planned: args.planned,
    budgetType: 'variable',
    frequency: 'none'
  };
}
