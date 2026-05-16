import type {
  AppUserSettings,
  BudgetWarningThresholdPercent,
  SupportedCurrency,
  ThemePreference
} from '../types/models';
import { DEFAULT_APP_USER_SETTINGS } from '../types/models';

function isThemePreference(v: unknown): v is ThemePreference {
  return v === 'system' || v === 'light' || v === 'dark';
}

function isSupportedCurrency(v: unknown): v is SupportedCurrency {
  return v === 'CAD' || v === 'USD' || v === 'EUR' || v === 'GBP';
}

function isThreshold(v: unknown): v is BudgetWarningThresholdPercent {
  return v === 75 || v === 90 || v === 100;
}

/// Merge persisted / partial JSON into a complete `AppUserSettings` object.
export function mergeAppUserSettings(raw: unknown): AppUserSettings {
  const merged: AppUserSettings = { ...DEFAULT_APP_USER_SETTINGS };
  if (!raw || typeof raw !== 'object') return merged;
  const o = raw as Record<string, unknown>;
  if (isThemePreference(o.themePreference)) merged.themePreference = o.themePreference;
  if (isSupportedCurrency(o.defaultCurrency)) merged.defaultCurrency = o.defaultCurrency;
  if (typeof o.monthStartDay === 'number' && o.monthStartDay >= 1 && o.monthStartDay <= 28) {
    merged.monthStartDay = Math.floor(o.monthStartDay);
  }
  if (isThreshold(o.budgetWarningThresholdPercent)) {
    merged.budgetWarningThresholdPercent = o.budgetWarningThresholdPercent;
  }
  if (typeof o.billDueRemindersEnabled === 'boolean') merged.billDueRemindersEnabled = o.billDueRemindersEnabled;
  if (typeof o.budgetWarningRemindersEnabled === 'boolean') {
    merged.budgetWarningRemindersEnabled = o.budgetWarningRemindersEnabled;
  }
  if (typeof o.weeklySpendingSummaryEnabled === 'boolean') {
    merged.weeklySpendingSummaryEnabled = o.weeklySpendingSummaryEnabled;
  }
  return merged;
}
