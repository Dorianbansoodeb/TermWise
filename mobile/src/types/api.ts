export type IncomeSource = {
  name: string;
  type: 'coop' | 'part_time' | 'other';
  hourlyWage: number;
  hoursPerWeek: number;
  payFrequency: 'weekly' | 'biweekly' | 'monthly';
  estimatedTaxRate: number;
};

export type ExpenseCategory = {
  name: string;
  plannedMonthlyAmount: number;
};

export type TuitionPayment = {
  amount: number;
  dueDate: string;
  description: string;
};

export type FundingSource = {
  name: string;
  amount: number;
  type: 'loan' | 'scholarship' | 'bursary' | 'gift' | 'extra_income';
};

export type SavingsGoal = {
  name: string;
  targetAmount: number;
  currentSavedAmount: number;
};

export type PlanningPayload = {
  incomeSources: IncomeSource[];
  expenseCategories: ExpenseCategory[];
  tuitionPayments: TuitionPayment[];
  fundingSources: FundingSource[];
  savingsGoals: SavingsGoal[];
};

export type TransactionPayload = {
  type: 'income' | 'expense';
  category: string;
  description: string;
  amount: number;
  occurredAt?: string;
};

export type DashboardResponse = {
  monthlyIncomeActual: number;
  monthlyExpenseActual: number;
  monthlyBalance: number;
  plannedMonthlyExpenses: number;
  planVsActualDelta: number;
  categoryProgress: { category: string; planned: number; actual: number; percentUsed: number }[];
  savingsProgress: { name: string; target: number; current: number; percent: number }[];
  messages: string[];
};
