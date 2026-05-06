import { Router } from 'express';
import { z } from 'zod';
import { Transaction } from '../models/Transaction';

const router = Router();

const transactionSchema = z.object({
  type: z.enum(['income', 'expense']),
  category: z.string().min(1),
  description: z.string().default(''),
  amount: z.number().positive(),
  occurredAt: z.string().optional()
});

router.get('/', async (req, res) => {
  const transactions = await Transaction.find({ userId: req.userId }).sort({ occurredAt: -1 }).limit(200);
  return res.json(transactions);
});

router.post('/', async (req, res) => {
  const parsed = transactionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: 'Invalid transaction payload', issues: parsed.error.issues });
  }

  const txn = await Transaction.create({
    ...parsed.data,
    userId: req.userId,
    occurredAt: parsed.data.occurredAt ? new Date(parsed.data.occurredAt) : new Date()
  });

  return res.status(201).json(txn);
});

export default router;
