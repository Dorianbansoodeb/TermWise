import AsyncStorage from '@react-native-async-storage/async-storage';
import type { ChartRange, PersistedState } from '../types/models';
import { buildDemoState } from './demoData';
import { isSameMonth, monthKey, parseCalendarDate } from '../utils/date';
import { mergeAppUserSettings } from '../utils/appUserSettings';

const STORAGE_KEY = '@termwise/persisted-state-v1';

function normalizeVariableChartRange(value: unknown): ChartRange {
  // Legacy installs may still have `oneWeek` (same 7-day window as sevenDays).
  if (value === 'oneWeek' || value === 'sevenDays') return 'sevenDays';
  if (value === 'thirtyDays') return 'thirtyDays';
  if (value === 'currentMonth') return 'currentMonth';
  return 'currentMonth';
}

/// When persisted demo data is from a prior month, seed the current month so
/// charts and dashboard math have expenses/income to plot.
export function prepareStateForReferenceMonth(
  state: PersistedState,
  referenceDate: Date
): PersistedState {
  const mk = monthKey(referenceDate);
  const hasExpenseThisMonth = state.transactions.some(
    (t) => t.type === 'expense' && isSameMonth(parseCalendarDate(t.date), referenceDate)
  );
  let transactions = state.transactions;
  if (!hasExpenseThisMonth && state.transactions.some((t) => t.type === 'expense')) {
    const demo = buildDemoState(referenceDate);
    transactions = [...state.transactions, ...demo.transactions];
  }

  const monthlySettingsByMonth = { ...state.monthlySettingsByMonth };
  if (!monthlySettingsByMonth[mk]) {
    monthlySettingsByMonth[mk] = {
      monthKey: mk,
      availableToBudget: 2300,
      desiredSavingsRate: 0.15
    };
  }

  return { ...state, transactions, monthlySettingsByMonth };
}

export async function loadPersistedState(): Promise<PersistedState | null> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as PersistedState;
    if (!parsed || parsed.schemaVersion !== 1) return null;
    parsed.variableChartRange = normalizeVariableChartRange(parsed.variableChartRange);
    parsed.appUserSettings = mergeAppUserSettings(parsed.appUserSettings);
    return parsed;
  } catch (err) {
    console.warn('[termwise] failed to load persisted state', err);
    return null;
  }
}

export async function savePersistedState(state: PersistedState): Promise<void> {
  try {
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (err) {
    console.warn('[termwise] failed to save persisted state', err);
  }
}

export async function clearPersistedState(): Promise<void> {
  try {
    await AsyncStorage.removeItem(STORAGE_KEY);
  } catch {
    /* noop */
  }
}
