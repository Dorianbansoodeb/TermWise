import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState
} from 'react';
import type {
  AppUserSettings,
  BudgetItem,
  ChartMode,
  ChartRange,
  MonthlySettings,
  PendingIncomePrompt,
  PendingUndoBar,
  PersistedState,
  TransactionItem
} from '../types/models';
import { buildDemoState } from './demoData';
import { loadPersistedState, prepareStateForReferenceMonth, savePersistedState } from './storage';
import { monthKey } from '../utils/date';
import { mergeAppUserSettings } from '../utils/appUserSettings';
import { formatCurrencyWith } from '../utils/format';
import {
  actualPaidForBill,
  availableToBudgetForMonth,
  netExpenseAmount,
  resolvedSavingsTarget
} from '../utils/financeCalculator';

// MARK: - UUID

function uuid(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

// MARK: - Context shape

export interface AppContextValue {
  // Data
  transactions: TransactionItem[];
  budgetItems: BudgetItem[];
  settingsForMonth: MonthlySettings;
  monthlyNote: string;
  /** All persisted month keys → note text (Profile month detail, etc.). */
  monthlyNotes: Record<string, string>;
  chartMode: ChartMode;
  variableChartRange: ChartRange;
  /// Derived
  availableToBudget: number;
  savingsTarget: number;
  /// Loaded flag — UI shows splash until storage is read.
  isHydrated: boolean;
  /** False until the user finishes first-run onboarding. */
  hasCompletedOnboarding: boolean;
  /// Reference "now" — fixed at first hydration so chart slot math is stable
  /// within a single render.
  referenceDate: Date;
  /** Persisted profile / Settings (theme, currency, reminders flags, …). */
  appUserSettings: AppUserSettings;
  /** Format amounts using `appUserSettings.defaultCurrency`. */
  formatMoney(value: number, opts?: { compact?: boolean }): string;

  // Mutations
  addTransaction(input: {
    amount: number;
    name?: string;
    category: string;
    note?: string;
    date?: Date;
    type: 'expense' | 'income';
    savedApplied?: number;
    source?: string;
    billId?: string;
    undoable?: boolean;
  }): TransactionItem;
  removeTransaction(id: string, opts?: { withUndo?: boolean }): void;
  markBillAsPaid(billId: string): void;
  /** Patch any subset of a BudgetItem (name / planned limit / dueDay / etc.). */
  updateBudgetItem(id: string, patch: Partial<Omit<BudgetItem, 'id'>>): void;
  /** Append a budget row; assigns a new unique `id` and persists with the rest of app state. */
  addBudgetItem(draft: Omit<BudgetItem, 'id'>): void;
  setAvailableToBudget(amount: number): void;
  setSavingsTarget(amount: number | undefined): void;
  setDesiredSavingsRate(rate: number): void;
  setMonthlyNote(note: string): void;
  setMonthlyNoteForMonth(monthKey: string, note: string): void;
  setChartMode(mode: ChartMode): void;
  setVariableChartRange(range: ChartRange): void;
  updateAppUserSettings(patch: Partial<AppUserSettings>): void;
  resolveIncomePrompt(choice: 'addToBudget' | 'keepAsReserve' | 'cancel'): void;
  dismissUndoBar(opts?: { performAction?: boolean }): void;
  /// Drops local AsyncStorage state and reseeds the demo data.
  resetToDemo(): Promise<void>;
  /** Marks first-run onboarding complete and persists. */
  completeOnboarding(): void;

  // Transient UI
  pendingIncomePrompt: PendingIncomePrompt | null;
  pendingUndoBar: PendingUndoBar | null;
}

const Ctx = createContext<AppContextValue | null>(null);

const UNDO_DURATION_MS = 5000;

// MARK: - Provider

export function AppStateProvider({ children }: { children: React.ReactNode }) {
  const [isHydrated, setHydrated] = useState(false);
  const [referenceDate] = useState<Date>(() => new Date());

  const [transactions, setTransactions] = useState<TransactionItem[]>([]);
  const [budgetItems, setBudgetItems] = useState<BudgetItem[]>([]);
  const [monthlySettingsByMonth, setMonthlySettingsByMonth] = useState<
    Record<string, MonthlySettings>
  >({});
  const [monthlyNotes, setMonthlyNotes] = useState<Record<string, string>>({});
  const [chartMode, setChartModeState] = useState<ChartMode>('variable');
  const [variableChartRange, setVariableChartRangeState] = useState<ChartRange>('currentMonth');
  const [appUserSettings, setAppUserSettings] = useState(() => mergeAppUserSettings(undefined));
  const [hasCompletedOnboarding, setHasCompletedOnboarding] = useState(false);
  const appUserSettingsRef = useRef(appUserSettings);
  appUserSettingsRef.current = appUserSettings;
  const hasCompletedOnboardingRef = useRef(hasCompletedOnboarding);
  hasCompletedOnboardingRef.current = hasCompletedOnboarding;

  const [pendingIncomePrompt, setPendingIncomePrompt] = useState<PendingIncomePrompt | null>(null);
  const [pendingUndoBar, setPendingUndoBar] = useState<PendingUndoBar | null>(null);
  const undoTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const currentMonthKey = monthKey(referenceDate);

  // MARK: load + persist

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const stored = await loadPersistedState();
      const base = stored ?? buildDemoState(referenceDate);
      const initial = prepareStateForReferenceMonth(base, referenceDate);
      if (cancelled) return;
      applyPersistedState(initial);
      const migrated =
        !!stored &&
        (initial.transactions.length !== stored.transactions.length ||
          Object.keys(initial.monthlySettingsByMonth).length !==
            Object.keys(stored.monthlySettingsByMonth).length);
      if (!stored || migrated) {
        await savePersistedState(initial);
      }
      setHydrated(true);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  function applyPersistedState(state: PersistedState) {
    setTransactions(state.transactions);
    setBudgetItems(state.budgetItems);
    setMonthlySettingsByMonth(state.monthlySettingsByMonth);
    setMonthlyNotes(state.monthlyNotes);
    setChartModeState(state.chartMode);
    setVariableChartRangeState(state.variableChartRange);
    setAppUserSettings(mergeAppUserSettings(state.appUserSettings));
    setHasCompletedOnboarding(state.hasCompletedOnboarding);
  }

  useEffect(() => {
    if (!isHydrated) return;
    const snapshot: PersistedState = {
      schemaVersion: 1,
      transactions,
      budgetItems,
      monthlySettingsByMonth,
      monthlyNotes,
      chartMode,
      variableChartRange,
      appUserSettings,
      hasCompletedOnboarding
    };
    savePersistedState(snapshot);
  }, [
    isHydrated,
    transactions,
    budgetItems,
    monthlySettingsByMonth,
    monthlyNotes,
    chartMode,
    variableChartRange,
    appUserSettings,
    hasCompletedOnboarding
  ]);

  // MARK: settings helpers

  const settingsForMonth: MonthlySettings = useMemo(() => {
    const stored = monthlySettingsByMonth[currentMonthKey];
    if (stored) return stored;
    return { monthKey: currentMonthKey, desiredSavingsRate: 0.15 };
  }, [monthlySettingsByMonth, currentMonthKey]);

  const monthlyNote = monthlyNotes[currentMonthKey] ?? '';

  const availableToBudget = useMemo(
    () => availableToBudgetForMonth(transactions, settingsForMonth, referenceDate),
    [transactions, settingsForMonth, referenceDate]
  );

  const savingsTarget = useMemo(
    () => resolvedSavingsTarget(availableToBudget, settingsForMonth),
    [availableToBudget, settingsForMonth]
  );

  const updateSettings = useCallback(
    (patch: Partial<MonthlySettings>) => {
      setMonthlySettingsByMonth((prev) => {
        const existing = prev[currentMonthKey] ?? {
          monthKey: currentMonthKey,
          desiredSavingsRate: 0.15
        };
        const next: MonthlySettings = { ...existing, ...patch, monthKey: currentMonthKey };
        return { ...prev, [currentMonthKey]: next };
      });
    },
    [currentMonthKey]
  );

  // MARK: undo helpers

  const scheduleUndo = useCallback((bar: PendingUndoBar) => {
    if (undoTimerRef.current) clearTimeout(undoTimerRef.current);
    setPendingUndoBar(bar);
    undoTimerRef.current = setTimeout(() => {
      setPendingUndoBar(null);
      undoTimerRef.current = null;
    }, UNDO_DURATION_MS);
  }, []);

  const dismissUndoBar = useCallback<AppContextValue['dismissUndoBar']>(
    (opts) => {
      const bar = pendingUndoBar;
      if (undoTimerRef.current) {
        clearTimeout(undoTimerRef.current);
        undoTimerRef.current = null;
      }
      setPendingUndoBar(null);
      if (!opts?.performAction || !bar) return;
      const action = bar.action;
      if (action.kind === 'restoreRemovedTransaction') {
        const txn = action.transaction;
        setTransactions((prev) =>
          prev.find((t) => t.id === txn.id) ? prev : [...prev, txn]
        );
      } else if (action.kind === 'undoMarkAsPaid') {
        setTransactions((prev) => prev.filter((t) => t.id !== action.transactionId));
      }
    },
    [pendingUndoBar]
  );

  // MARK: mutations

  const addTransaction = useCallback<AppContextValue['addTransaction']>(
    (input) => {
      const now = new Date();
      const txn: TransactionItem = {
        id: uuid(),
        amount: Math.max(0, input.amount),
        name: input.name?.trim() || input.category,
        category: input.category,
        note: input.note ?? '',
        date: (input.date ?? now).toISOString(),
        createdAt: now.toISOString(),
        type: input.type,
        savedApplied: Math.max(0, input.savedApplied ?? 0),
        source: input.source,
        billId: input.billId,
        undoable: input.undoable ?? false
      };
      setTransactions((prev) => [...prev, txn]);
      if (txn.type === 'income') {
        setPendingIncomePrompt({
          transactionId: txn.id,
          amount: txn.amount,
          categoryName: txn.category
        });
      }
      // When an expense lands on a recurring bill and that payment finishes
      // off the planned amount, surface the same "Fully paid X" success +
      // undo snackbar that Mark-as-Paid uses. Undo simply removes the
      // synthetic transaction (mirrors the existing markBillAsPaid flow).
      if (txn.type === 'expense' && txn.billId) {
        const bill = budgetItems.find(
          (b) => b.id === txn.billId && b.budgetType === 'fixed'
        );
        if (bill) {
          const priorPaid = actualPaidForBill(bill, transactions, referenceDate);
          const newPaid = priorPaid + netExpenseAmount(txn);
          if (priorPaid < bill.planned && newPaid >= bill.planned) {
            scheduleUndo({
              message: `Fully paid ${bill.category}`,
              action: { kind: 'undoMarkAsPaid', billId: bill.id, transactionId: txn.id },
              createdAt: Date.now()
            });
          }
        }
      }
      return txn;
    },
    [budgetItems, transactions, referenceDate, scheduleUndo]
  );

  const removeTransaction = useCallback<AppContextValue['removeTransaction']>(
    (id, opts) => {
      const target = transactions.find((t) => t.id === id);
      if (!target) return;
      setTransactions((prev) => prev.filter((t) => t.id !== id));
      if (opts?.withUndo) {
        scheduleUndo({
          message: `Removed ${target.name || target.category}`,
          action: { kind: 'restoreRemovedTransaction', transaction: target },
          createdAt: Date.now()
        });
      }
    },
    [transactions, scheduleUndo]
  );

  const markBillAsPaid = useCallback<AppContextValue['markBillAsPaid']>(
    (billId) => {
      const bill = budgetItems.find((b) => b.id === billId && b.budgetType === 'fixed');
      if (!bill) return;
      const alreadyPaid = actualPaidForBill(bill, transactions, referenceDate);
      const remaining = Math.max(0, bill.planned - alreadyPaid);
      if (remaining <= 0) return;
      const now = new Date();
      const txn: TransactionItem = {
        id: uuid(),
        amount: remaining,
        name: bill.category,
        category: bill.category,
        note: '',
        date: now.toISOString(),
        createdAt: now.toISOString(),
        type: 'expense',
        savedApplied: 0,
        source: 'markAsPaid',
        billId: bill.id,
        undoable: true
      };
      setTransactions((prev) => [...prev, txn]);
      scheduleUndo({
        message: `Fully paid ${bill.category}`,
        action: { kind: 'undoMarkAsPaid', billId: bill.id, transactionId: txn.id },
        createdAt: Date.now()
      });
    },
    [budgetItems, transactions, referenceDate, scheduleUndo]
  );

  const updateBudgetItem = useCallback<AppContextValue['updateBudgetItem']>(
    (id, patch) => {
      setBudgetItems((prev) =>
        prev.map((item) => {
          if (item.id !== id) return item;
          const next: BudgetItem = { ...item, ...patch, id: item.id };
          if (typeof next.planned === 'number') {
            next.planned = Math.max(0, next.planned);
          }
          if (typeof next.category === 'string') {
            next.category = next.category.trim() || item.category;
          }
          return next;
        })
      );
    },
    []
  );

  const addBudgetItem = useCallback<AppContextValue['addBudgetItem']>((draft) => {
    const item: BudgetItem = { ...draft, id: uuid() };
    setBudgetItems((prev) => [...prev, item]);
  }, []);

  const setAvailableToBudget = useCallback<AppContextValue['setAvailableToBudget']>(
    (amount) => {
      updateSettings({ availableToBudget: Math.max(0, amount) });
    },
    [updateSettings]
  );

  const setSavingsTarget = useCallback<AppContextValue['setSavingsTarget']>(
    (amount) => {
      updateSettings({
        customSavingsTarget: amount === undefined ? undefined : Math.max(0, amount)
      });
    },
    [updateSettings]
  );

  const setDesiredSavingsRate = useCallback<AppContextValue['setDesiredSavingsRate']>(
    (rate) => {
      updateSettings({ desiredSavingsRate: Math.max(0, rate) });
    },
    [updateSettings]
  );

  const setMonthlyNote = useCallback<AppContextValue['setMonthlyNote']>(
    (note) => {
      setMonthlyNotes((prev) => ({ ...prev, [currentMonthKey]: note }));
    },
    [currentMonthKey]
  );

  const setMonthlyNoteForMonth = useCallback<AppContextValue['setMonthlyNoteForMonth']>(
    (monthKey, note) => {
      setMonthlyNotes((prev) => ({ ...prev, [monthKey]: note }));
    },
    []
  );

  const resolveIncomePrompt = useCallback<AppContextValue['resolveIncomePrompt']>(
    (choice) => {
      const prompt = pendingIncomePrompt;
      if (!prompt) return;
      if (choice === 'cancel') {
        // Cancel undoes the income transaction outright — the user did not
        // mean to record it. (Per Quick Add spec: "Prefer canceling the
        // income add if easier.")
        setTransactions((prev) => prev.filter((t) => t.id !== prompt.transactionId));
        setPendingIncomePrompt(null);
        return;
      }
      if (choice === 'addToBudget') {
        // Move the recorded income into the budget envelope override so future
        // months still derive from totalIncome by default.
        const current = settingsForMonth.availableToBudget ?? availableToBudget;
        updateSettings({ availableToBudget: Math.max(0, current) + prompt.amount });
      }
      // 'keepAsReserve' → leave availableToBudget alone (reserve grows naturally).
      setPendingIncomePrompt(null);
    },
    [pendingIncomePrompt, settingsForMonth, availableToBudget, updateSettings]
  );

  const setChartMode = useCallback((mode: ChartMode) => setChartModeState(mode), []);
  const setVariableChartRange = useCallback(
    (range: ChartRange) => setVariableChartRangeState(range),
    []
  );

  const updateAppUserSettings = useCallback<AppContextValue['updateAppUserSettings']>((patch) => {
    setAppUserSettings((prev) => ({ ...prev, ...patch }));
  }, []);

  const formatMoney = useCallback<AppContextValue['formatMoney']>(
    (value, opts) => formatCurrencyWith(value, appUserSettings.defaultCurrency, opts ?? {}),
    [appUserSettings.defaultCurrency]
  );

  const resetToDemo = useCallback(async () => {
    const next = buildDemoState(new Date());
    const kept = appUserSettingsRef.current;
    setTransactions(next.transactions);
    setBudgetItems(next.budgetItems);
    setMonthlySettingsByMonth(next.monthlySettingsByMonth);
    setMonthlyNotes(next.monthlyNotes);
    setChartModeState(next.chartMode);
    setVariableChartRangeState(next.variableChartRange);
    setAppUserSettings(kept);
    await savePersistedState({
      schemaVersion: 1,
      transactions: next.transactions,
      budgetItems: next.budgetItems,
      monthlySettingsByMonth: next.monthlySettingsByMonth,
      monthlyNotes: next.monthlyNotes,
      chartMode: next.chartMode,
      variableChartRange: next.variableChartRange,
      appUserSettings: kept,
      hasCompletedOnboarding: hasCompletedOnboardingRef.current
    });
  }, []);

  const completeOnboarding = useCallback(() => {
    setHasCompletedOnboarding(true);
  }, []);

  const value: AppContextValue = {
    transactions,
    budgetItems,
    settingsForMonth,
    monthlyNote,
    monthlyNotes,
    chartMode,
    variableChartRange,
    availableToBudget,
    savingsTarget,
    isHydrated,
    hasCompletedOnboarding,
    referenceDate,
    appUserSettings,
    formatMoney,
    addTransaction,
    removeTransaction,
    markBillAsPaid,
    updateBudgetItem,
    addBudgetItem,
    setAvailableToBudget,
    setSavingsTarget,
    setDesiredSavingsRate,
    setMonthlyNote,
    setMonthlyNoteForMonth,
    setChartMode,
    setVariableChartRange,
    updateAppUserSettings,
    resolveIncomePrompt,
    dismissUndoBar,
    resetToDemo,
    completeOnboarding,
    pendingIncomePrompt,
    pendingUndoBar
  };

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAppState(): AppContextValue {
  const ctx = useContext(Ctx);
  if (!ctx) {
    throw new Error('useAppState must be used within <AppStateProvider>');
  }
  return ctx;
}
