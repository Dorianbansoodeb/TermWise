import { Router } from 'express';
import { z } from 'zod';
import { Planning } from '../models/Planning';

const router = Router();

const planningSchema = z.object({
  incomeSources: z
    .array(
      z.object({
        name: z.string(),
        type: z.enum(['coop', 'part_time', 'other']),
        hourlyWage: z.number().nonnegative(),
        hoursPerWeek: z.number().nonnegative(),
        payFrequency: z.enum(['weekly', 'biweekly', 'monthly']),
        estimatedTaxRate: z.number().min(0).max(100)
      })
    )
    .default([]),
  expenseCategories: z
    .array(
      z.object({
        name: z.string(),
        plannedMonthlyAmount: z.number().nonnegative()
      })
    )
    .default([]),
  tuitionPayments: z
    .array(
      z.object({
        amount: z.number().nonnegative(),
        dueDate: z.string(),
        description: z.string().default('')
      })
    )
    .default([]),
  fundingSources: z
    .array(
      z.object({
        name: z.string(),
        amount: z.number().nonnegative(),
        type: z.enum(['loan', 'scholarship', 'bursary', 'gift', 'extra_income'])
      })
    )
    .default([]),
  savingsGoals: z
    .array(
      z.object({
        name: z.string(),
        targetAmount: z.number().nonnegative(),
        currentSavedAmount: z.number().nonnegative()
      })
    )
    .default([])
});

router.get('/', async (req, res) => {
  const plan = await Planning.findOne({ userId: req.userId });
  return res.json(plan ?? null);
});

router.put('/', async (req, res) => {
  const parsed = planningSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: 'Invalid planning payload', issues: parsed.error.issues });
  }

  const payload = {
    ...parsed.data,
    tuitionPayments: parsed.data.tuitionPayments.map((t) => ({
      ...t,
      dueDate: new Date(t.dueDate)
    }))
  };

  const plan = await Planning.findOneAndUpdate(
    { userId: req.userId },
    { ...payload, userId: req.userId },
    { upsert: true, new: true }
  );

  return res.json(plan);
});

export default router;
