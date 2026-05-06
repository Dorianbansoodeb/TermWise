import { Planning } from '../models/Planning';
import { Transaction } from '../models/Transaction';
import { endOfMonth, startOfMonth } from '../utils/dates';

type CategoryBreakdown = {
  category: string;
  expected: number;
  actual: number;
  percentUsed: number;
};

const monthWindow = (year: number, month: number) => {
  const start = new Date(year, month - 1, 1, 0, 0, 0, 0);
  const end = new Date(year, month, 0, 23, 59, 59, 999);
  return { start, end };
};

const toMonthLabel = (date: Date): string =>
  `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;

export const getUserSettings = async (userId: string) => {
  const plan = await Planning.findOne({ userId }).lean();
  return (
    plan?.settings ?? {
      userFirstName: 'Student',
      currencyCode: 'USD',
      manualMonthlyLimit: null,
      desiredSavingsRate: 15
    }
  );
};

export const updateUserSettings = async (
  userId: string,
  settings: {
    userFirstName?: string;
    currencyCode?: string;
    manualMonthlyLimit?: number | null;
    desiredSavingsRate?: number;
  }
) => {
  const plan = await Planning.findOneAndUpdate(
    { userId },
    {
      userId,
      $set: {
        ...(settings.userFirstName !== undefined ? { 'settings.userFirstName': settings.userFirstName } : {}),
        ...(settings.currencyCode !== undefined ? { 'settings.currencyCode': settings.currencyCode } : {}),
        ...(settings.manualMonthlyLimit !== undefined
          ? { 'settings.manualMonthlyLimit': settings.manualMonthlyLimit }
          : {}),
        ...(settings.desiredSavingsRate !== undefined
          ? { 'settings.desiredSavingsRate': settings.desiredSavingsRate }
          : {})
      }
    },
    { upsert: true, new: true }
  ).lean();

  return plan?.settings;
};

export const getHomeAnalytics = async (userId: string) => {
  const plan = await Planning.findOne({ userId }).lean();
  const now = new Date();
  const start = startOfMonth(now);
  const end = endOfMonth(now);

  const txns = await Transaction.find({ userId, occurredAt: { $gte: start, $lte: end } }).lean();

  const monthlyIncome = txns.filter((t) => t.type === 'income').reduce((sum, t) => sum + t.amount, 0);
  const monthlyExpense = txns.filter((t) => t.type === 'expense').reduce((sum, t) => sum + t.amount, 0);

  const plannedMonthlyExpenses =
    plan?.expenseCategories.reduce((sum, c) => sum + c.plannedMonthlyAmount, 0) ?? 0;
  const manualLimit = plan?.settings?.manualMonthlyLimit ?? null;
  const effectiveLimit = manualLimit ?? plannedMonthlyExpenses;

  const day = now.getDate();
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const avgPerDay = monthlyExpense / Math.max(day, 1);
  const projectedEndOfMonthSpend = avgPerDay * daysInMonth;

  const categoryProgress: CategoryBreakdown[] = (plan?.expenseCategories ?? []).map((cat) => {
    const actual = txns
      .filter((t) => t.type === 'expense' && t.category.toLowerCase().includes(cat.name.toLowerCase()))
      .reduce((sum, t) => sum + t.amount, 0);
    return {
      category: cat.name,
      expected: cat.plannedMonthlyAmount,
      actual,
      percentUsed: cat.plannedMonthlyAmount > 0 ? Math.round((actual / cat.plannedMonthlyAmount) * 100) : 0
    };
  });

  return {
    settings: plan?.settings ?? null,
    summary: {
      monthlyIncome,
      monthlyExpense,
      plannedMonthlyExpenses,
      effectiveMonthlyLimit: effectiveLimit,
      expectedTotalSaved: Math.max(0, monthlyIncome - monthlyExpense),
      projectedEndOfMonthSpend,
      isPredictedOverLimit: projectedEndOfMonthSpend > effectiveLimit
    },
    categoryProgress
  };
};

export const getMonthlyHistory = async (userId: string, months = 6) => {
  const plan = await Planning.findOne({ userId }).lean();
  const expectedMonthly = plan?.expenseCategories.reduce((sum, c) => sum + c.plannedMonthlyAmount, 0) ?? 0;
  const now = new Date();

  const output: Array<{
    month: string;
    expected: number;
    actual: number;
    saved: number;
    percentUsed: number;
    isOver: boolean;
  }> = [];

  for (let i = months - 1; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const { start, end } = monthWindow(d.getFullYear(), d.getMonth() + 1);
    const txns = await Transaction.find({ userId, occurredAt: { $gte: start, $lte: end } }).lean();
    const actual = txns.filter((t) => t.type === 'expense').reduce((sum, t) => sum + t.amount, 0);
    const saved = expectedMonthly - actual;
    const percentUsed = expectedMonthly > 0 ? Math.round((actual / expectedMonthly) * 100) : 0;

    output.push({
      month: toMonthLabel(d),
      expected: expectedMonthly,
      actual,
      saved,
      percentUsed,
      isOver: actual > expectedMonthly
    });
  }

  return output;
};

export const getMonthDetail = async (userId: string, year: number, month: number) => {
  const plan = await Planning.findOne({ userId }).lean();
  const { start, end } = monthWindow(year, month);
  const txns = await Transaction.find({ userId, occurredAt: { $gte: start, $lte: end } }).lean();

  const expectedMonthly = plan?.expenseCategories.reduce((sum, c) => sum + c.plannedMonthlyAmount, 0) ?? 0;
  const totalActualExpense = txns.filter((t) => t.type === 'expense').reduce((sum, t) => sum + t.amount, 0);
  const totalActualIncome = txns.filter((t) => t.type === 'income').reduce((sum, t) => sum + t.amount, 0);

  const categoryBreakdown: CategoryBreakdown[] = (plan?.expenseCategories ?? []).map((cat) => {
    const actual = txns
      .filter((t) => t.type === 'expense' && t.category.toLowerCase().includes(cat.name.toLowerCase()))
      .reduce((sum, t) => sum + t.amount, 0);
    return {
      category: cat.name,
      expected: cat.plannedMonthlyAmount,
      actual,
      percentUsed: cat.plannedMonthlyAmount > 0 ? Math.round((actual / cat.plannedMonthlyAmount) * 100) : 0
    };
  });

  return {
    month: `${year}-${String(month).padStart(2, '0')}`,
    summary: {
      expectedExpense: expectedMonthly,
      actualExpense: totalActualExpense,
      actualIncome: totalActualIncome,
      saved: expectedMonthly - totalActualExpense,
      percentUsed: expectedMonthly > 0 ? Math.round((totalActualExpense / expectedMonthly) * 100) : 0,
      isOver: totalActualExpense > expectedMonthly
    },
    categoryBreakdown
  };
};
