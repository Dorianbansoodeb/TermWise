import AsyncStorage from '@react-native-async-storage/async-storage';
import type {
  AppUserSettings,
  BudgetItem,
  ChartMode,
  ChartRange,
  MonthlySettings,
  PersistedState,
  TransactionItem
} from '../types/models';
import { buildDemoState } from './demoData';
import { isSameMonth, monthKey, parseCalendarDate } from '../utils/date';
import { mergeAppUserSettings } from '../utils/appUserSettings';

const STORAGE_KEY = '@termwise/persisted-state-v1';
const CURRENT_SCHEMA_VERSION = 1;

type RawPersistedState = Record<string, unknown>;

function normalizeVariableChartRange(value: unknown): ChartRange {
  // Legacy installs may still have `oneWeek` (same 7-day window as sevenDays).
  if (value === 'oneWeek' || value === 'sevenDays') return 'sevenDays';
  if (value === 'thirtyDays') return 'thirtyDays';
  if (value === 'currentMonth') return 'currentMonth';
  return 'currentMonth';
}

function normalizeChartMode(value: unknown): ChartMode {
  return value === 'total' ? 'total' : 'variable';
}

function migrateSchemaV1(raw: RawPersistedState): PersistedState {
  return {
    schemaVersion: 1,
    transactions: Array.isArray(raw.transactions) ? (raw.transactions as TransactionItem[]) : [],
    budgetItems: Array.isArray(raw.budgetItems) ? (raw.budgetItems as BudgetItem[]) : [],
    monthlySettingsByMonth:
      raw.monthlySettingsByMonth && typeof raw.monthlySettingsByMonth === 'object'
        ? (raw.monthlySettingsByMonth as Record<string, MonthlySettings>)
        : {},
    monthlyNotes:
      raw.monthlyNotes && typeof raw.monthlyNotes === 'object'
        ? (raw.monthlyNotes as Record<string, string>)
        : {},
    chartMode: normalizeChartMode(raw.chartMode),
    variableChartRange: normalizeVariableChartRange(raw.variableChartRange),
    appUserSettings: mergeAppUserSettings(raw.appUserSettings as AppUserSettings | undefined),
    lastDemoSeedMonthKey:
      typeof raw.lastDemoSeedMonthKey === 'string' ? raw.lastDemoSeedMonthKey : undefined
  };
}

/// Upgrade raw JSON from AsyncStorage to the current `PersistedState` shape.
export function migratePersistedState(raw: unknown): PersistedState | null {
  if (!raw || typeof raw !== 'object') return null;

  const parsed = raw as RawPersistedState;
  const version = parsed.schemaVersion;
  if (typeof version !== 'number' || version < 1 || version > CURRENT_SCHEMA_VERSION) {
    return null;
  }

  // Add future version steps here (e.g. migrateSchemaV2 → migrateSchemaV1).
  let state: PersistedState;
  switch (version) {
    case 1:
      state = migrateSchemaV1(parsed);
      break;
    default:
      return null;
  }

  state.variableChartRange = normalizeVariableChartRange(state.variableChartRange);
  state.appUserSettings = mergeAppUserSettings(state.appUserSettings);
  return state;
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
  const alreadySeededThisMonth = state.lastDemoSeedMonthKey === mk;

  let transactions = state.transactions;
  let lastDemoSeedMonthKey = state.lastDemoSeedMonthKey;
  if (
    !hasExpenseThisMonth &&
    !alreadySeededThisMonth &&
    state.transactions.some((t) => t.type === 'expense')
  ) {
    const demo = buildDemoState(referenceDate);
    transactions = [...state.transactions, ...demo.transactions];
    lastDemoSeedMonthKey = mk;
  }

  const monthlySettingsByMonth = { ...state.monthlySettingsByMonth };
  if (!monthlySettingsByMonth[mk]) {
    monthlySettingsByMonth[mk] = {
      monthKey: mk,
      availableToBudget: 2300,
      desiredSavingsRate: 0.15
    };
  }

  return { ...state, transactions, monthlySettingsByMonth, lastDemoSeedMonthKey };
}

export async function loadPersistedState(): Promise<PersistedState | null> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return migratePersistedState(JSON.parse(raw));
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
