import { Schema, model, InferSchemaType, Types } from 'mongoose';

const incomeSourceSchema = new Schema(
  {
    name: { type: String, required: true },
    type: { type: String, enum: ['coop', 'part_time', 'other'], required: true },
    hourlyWage: { type: Number, default: 0 },
    hoursPerWeek: { type: Number, default: 0 },
    payFrequency: { type: String, enum: ['weekly', 'biweekly', 'monthly'], default: 'biweekly' },
    estimatedTaxRate: { type: Number, default: 0 }
  },
  { _id: false }
);

const budgetCategorySchema = new Schema(
  {
    name: { type: String, required: true },
    plannedMonthlyAmount: { type: Number, required: true }
  },
  { _id: false }
);

const tuitionPaymentSchema = new Schema(
  {
    amount: { type: Number, required: true },
    dueDate: { type: Date, required: true },
    description: { type: String, default: '' }
  },
  { _id: false }
);

const fundingSourceSchema = new Schema(
  {
    name: { type: String, required: true },
    amount: { type: Number, required: true },
    type: {
      type: String,
      enum: ['loan', 'scholarship', 'bursary', 'gift', 'extra_income'],
      required: true
    }
  },
  { _id: false }
);

const savingsGoalSchema = new Schema(
  {
    name: { type: String, required: true },
    targetAmount: { type: Number, required: true },
    currentSavedAmount: { type: Number, default: 0 }
  },
  { _id: false }
);

const settingsSchema = new Schema(
  {
    userFirstName: { type: String, default: 'Student' },
    currencyCode: { type: String, default: 'USD' },
    manualMonthlyLimit: { type: Number, default: null },
    desiredSavingsRate: { type: Number, default: 15 }
  },
  { _id: false }
);

const planningSchema = new Schema(
  {
    userId: { type: Types.ObjectId, ref: 'User', required: true, unique: true },
    incomeSources: { type: [incomeSourceSchema], default: [] },
    expenseCategories: { type: [budgetCategorySchema], default: [] },
    tuitionPayments: { type: [tuitionPaymentSchema], default: [] },
    fundingSources: { type: [fundingSourceSchema], default: [] },
    savingsGoals: { type: [savingsGoalSchema], default: [] },
    settings: { type: settingsSchema, default: () => ({}) }
  },
  { timestamps: true }
);

export type PlanningDocument = InferSchemaType<typeof planningSchema>;
export const Planning = model<PlanningDocument>('Planning', planningSchema);
