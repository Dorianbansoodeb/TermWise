import { Router } from 'express';
import { z } from 'zod';
import { getUserSettings, updateUserSettings } from '../services/analytics';

const router = Router();

const settingsSchema = z.object({
  userFirstName: z.string().min(1).max(80).optional(),
  currencyCode: z.enum(['USD', 'CAD', 'EUR', 'GBP']).optional(),
  manualMonthlyLimit: z.number().nonnegative().nullable().optional(),
  desiredSavingsRate: z.number().min(0).max(100).optional()
});

router.get('/', async (req, res) => {
  const data = await getUserSettings(String(req.userId));
  return res.json(data);
});

router.put('/', async (req, res) => {
  const parsed = settingsSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: 'Invalid settings payload', issues: parsed.error.issues });
  }

  const data = await updateUserSettings(String(req.userId), parsed.data);
  return res.json(data);
});

export default router;
