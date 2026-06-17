import type {
  BudgetItem,
  MonthlySettings,
  PersistedState,
  TransactionItem
} from '../types/models';
import { DEFAULT_APP_USER_SETTINGS } from '../types/models';
import { addDays, dayKey, monthKey, calendarDateISO } from '../utils/date';

function uuid(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

function isoForDay(now: Date, dayOffset: number, hour = 10, minute = 0): string {
  const d = addDays(now, dayOffset);
  d.setHours(hour, minute, 0, 0);
  return calendarDateISO(d);
}

/// Build a realistic student demo snapshot anchored at `now`. Spread across
/// today and the prior 18 days so the chart has data immediately.
export function buildDemoState(now: Date = new Date()): PersistedState {
  const currentMonthKey = monthKey(now);

  const rent: BudgetItem = {
    id: uuid(),
    category: 'Rent',
    planned: 950,
    budgetType: 'fixed',
    frequency: 'monthly',
    dueDay: 1
  };
  const phone: BudgetItem = {
    id: uuid(),
    category: 'Phone',
    planned: 55,
    budgetType: 'fixed',
    frequency: 'monthly',
    dueDay: 15
  };
  const tuitionSavings: BudgetItem = {
    id: uuid(),
    category: 'Tuition Savings',
    planned: 250,
    budgetType: 'fixed',
    frequency: 'monthly',
    dueDay: 28
  };
  const subscriptions: BudgetItem = {
    id: uuid(),
    category: 'Subscriptions',
    planned: 22,
    budgetType: 'fixed',
    frequency: 'monthly',
    dueDay: 10
  };

  const groceries: BudgetItem = {
    id: uuid(),
    category: 'Groceries',
    planned: 280,
    budgetType: 'variable',
    frequency: 'none'
  };
  const eatingOut: BudgetItem = {
    id: uuid(),
    category: 'Eating Out',
    planned: 150,
    budgetType: 'variable',
    frequency: 'none'
  };
  const transportation: BudgetItem = {
    id: uuid(),
    category: 'Transportation',
    planned: 90,
    budgetType: 'variable',
    frequency: 'none'
  };
  const coffee: BudgetItem = {
    id: uuid(),
    category: 'Coffee',
    planned: 40,
    budgetType: 'variable',
    frequency: 'none'
  };
  const fun: BudgetItem = {
    id: uuid(),
    category: 'Fun',
    planned: 70,
    budgetType: 'variable',
    frequency: 'none'
  };

  const budgetItems: BudgetItem[] = [
    rent,
    phone,
    tuitionSavings,
    subscriptions,
    groceries,
    eatingOut,
    transportation,
    coffee,
    fun
  ];

  const transactions: TransactionItem[] = [];

  // Paychecks: biweekly co-op pay (~$1,250 net) on day 2 and day 16 of month.
  for (const offset of [-16, -2]) {
    transactions.push({
      id: uuid(),
      amount: 1250,
      name: 'Co-op Paycheck',
      category: 'Co-op Pay',
      note: '',
      date: isoForDay(now, offset, 9, 0),
      createdAt: isoForDay(now, offset, 9, 0),
      type: 'income',
      savedApplied: 0,
      undoable: false
    });
  }

  // Rent paid early in the month.
  transactions.push({
    id: uuid(),
    amount: 950,
    name: 'Rent',
    category: 'Rent',
    note: 'Auto-pay',
    date: isoForDay(now, -Math.max(now.getDate() - 1, 0), 7, 30),
    createdAt: isoForDay(now, -Math.max(now.getDate() - 1, 0), 7, 30),
    type: 'expense',
    savedApplied: 0,
    source: 'markAsPaid',
    billId: rent.id,
    undoable: false
  });

  // Phone bill not yet paid — left as unpaid intentionally so the
  // Recurring Bills card shows an "Unpaid" state on first open.

  // Subscriptions paid.
  transactions.push({
    id: uuid(),
    amount: 22,
    name: 'Subscriptions',
    category: 'Subscriptions',
    note: 'Music + cloud',
    date: isoForDay(now, -8, 12, 0),
    createdAt: isoForDay(now, -8, 12, 0),
    type: 'expense',
    savedApplied: 0,
    source: 'markAsPaid',
    billId: subscriptions.id,
    undoable: false
  });

  // Variable spending sprinkled across the last ~2 weeks.
  const variableEntries: { day: number; amount: number; name: string; category: string }[] = [
    { day: -14, amount: 42.18, name: 'Loblaws', category: 'Groceries' },
    { day: -13, amount: 6.75, name: 'Tim Hortons', category: 'Coffee' },
    { day: -12, amount: 18.4, name: 'Uber', category: 'Transportation' },
    { day: -11, amount: 22.5, name: 'Burrito Bowl', category: 'Eating Out' },
    { day: -10, amount: 51.0, name: 'Costco run', category: 'Groceries' },
    { day: -9, amount: 9.25, name: 'Bus pass top-up', category: 'Transportation' },
    { day: -8, amount: 14.6, name: 'Pizza w/ friends', category: 'Eating Out' },
    { day: -7, amount: 5.5, name: 'Latte', category: 'Coffee' },
    { day: -6, amount: 32.4, name: 'Sushi', category: 'Eating Out' },
    { day: -5, amount: 28.05, name: 'No Frills', category: 'Groceries' },
    { day: -4, amount: 12.0, name: 'Movie ticket', category: 'Fun' },
    { day: -3, amount: 4.95, name: 'Mocha', category: 'Coffee' },
    { day: -2, amount: 8.75, name: 'Pho lunch', category: 'Eating Out' },
    { day: -1, amount: 38.2, name: 'Loblaws', category: 'Groceries' },
    { day: 0, amount: 6.5, name: 'Starbucks', category: 'Coffee' }
  ];
  for (const entry of variableEntries) {
    transactions.push({
      id: uuid(),
      amount: entry.amount,
      name: entry.name,
      category: entry.category,
      note: '',
      date: isoForDay(now, entry.day, 13, 0),
      createdAt: isoForDay(now, entry.day, 13, 0),
      type: 'expense',
      savedApplied: 0,
      undoable: false
    });
  }

  const settings: MonthlySettings = {
    monthKey: currentMonthKey,
    availableToBudget: 2300,
    desiredSavingsRate: 0.15
  };

  return {
    schemaVersion: 1,
    transactions,
    budgetItems,
    monthlySettingsByMonth: { [currentMonthKey]: settings },
    monthlyNotes: {
      [currentMonthKey]: 'Light month — keep coffee runs under $40.'
    },
    chartMode: 'variable',
    variableChartRange: 'currentMonth',
    appUserSettings: { ...DEFAULT_APP_USER_SETTINGS },
    lastDemoSeedMonthKey: currentMonthKey
  };
}

// Helper for tests / debug if the consumer wants to verify the seed shape.
export { dayKey };
