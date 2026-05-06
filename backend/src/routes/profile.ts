import { Router } from 'express';
import { z } from 'zod';
import { Profile } from '../models/Profile';

const router = Router();

const profileSchema = z.object({
  schoolName: z.string().optional(),
  programName: z.string().optional(),
  termType: z.enum(['school', 'coop']).optional(),
  monthlyBudgetStartDay: z.number().min(1).max(28).optional()
});

router.get('/', async (req, res) => {
  const profile = await Profile.findOne({ userId: req.userId });
  return res.json(profile ?? null);
});

router.put('/', async (req, res) => {
  const parsed = profileSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: 'Invalid profile payload' });
  }

  const profile = await Profile.findOneAndUpdate(
    { userId: req.userId },
    { ...parsed.data, userId: req.userId },
    { upsert: true, new: true }
  );

  return res.json(profile);
});

export default router;
