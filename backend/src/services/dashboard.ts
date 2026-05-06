import { endOfMonth, startOfMonth } from '../utils/dates';
import { Planning } from '../models/Planning';
import { Transaction } from '../models/Transaction';

export const getDashboardSnapshot = async (userId: string) => {
  const plan = await Planning.findOne({ userId }).lean();

  const now = new Date();
  const start = startOfMonth(now);
  const end = endOfMonth(now);

  const txns = await Transaction.find({
    userId,
    occurredAt: { $gte: start, $lte: end }
  }).lean();

  const monthlyIncomeActual = txns
    .filter((t) => t.type === 'income')
    .reduce((sum, t) => sum + t.amount, 0);
  const monthlyExpenseActual = txns
    .filter((t) => t.type === 'expense')
    .reduce((sum, t) => sum + t.amount, 0);

  const plannedMonthlyExpenses =
    plan?.expenseCategories.reduce((sum, c) => sum + c.plannedMonthlyAmount, 0) ?? 0;

  const categoryProgress = (plan?.expenseCategories ?? []).map((c) => {
    const spent = txns
      .filter((t) => t.type === 'expense' && t.category.toLowerCase() === c.name.toLowerCase())
      .reduce((sum, t) => sum + t.amount, 0);

    return {
      category: c.name,
      planned: c.plannedMonthlyAmount,
      actual: spent,
      percentUsed: c.plannedMonthlyAmount > 0 ? Math.round((spent / c.plannedMonthlyAmount) * 100) : 0
    };
  });

  const savingsProgress = (plan?.savingsGoals ?? []).map((g) => ({
    name: g.name,
    target: g.targetAmount,
    current: g.currentSavedAmount,
    percent: g.targetAmount > 0 ? Math.round((g.currentSavedAmount / g.targetAmount) * 100) : 0
  }));

  const messages: string[] = [];
  categoryProgress.forEach((c) => {
    if (c.percentUsed >= 80 && c.percentUsed < 100) {
      messages.push(`You have used ${c.percentUsed}% of your ${c.category} budget this month.`);
    }
    if (c.percentUsed >= 100) {
      messages.push(`At this pace, you may exceed your ${c.category} budget.`);
    }
  });

  return {
    monthlyIncomeActual,
    monthlyExpenseActual,
    monthlyBalance: monthlyIncomeActual - monthlyExpenseActual,
    plannedMonthlyExpenses,
    planVsActualDelta: plannedMonthlyExpenses - monthlyExpenseActual,
    categoryProgress,
    savingsProgress,
    messages
  };
};
