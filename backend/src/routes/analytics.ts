import { Router } from 'express';
import { z } from 'zod';
import { getHomeAnalytics, getMonthDetail, getMonthlyHistory } from '../services/analytics';

const router = Router();

router.get('/home', async (req, res) => {
  const data = await getHomeAnalytics(String(req.userId));
  return res.json(data);
});

router.get('/months', async (req, res) => {
  const querySchema = z.object({
    months: z.coerce.number().int().min(1).max(24).optional()
  });

  const parsed = querySchema.safeParse(req.query);
  if (!parsed.success) {
    return res.status(400).json({ message: 'Invalid query params', issues: parsed.error.issues });
  }

  const data = await getMonthlyHistory(String(req.userId), parsed.data.months ?? 6);
  return res.json(data);
});

router.get('/months/:month/detail', async (req, res) => {
  const paramsSchema = z.object({
    month: z.string().regex(/^\d{4}-\d{2}$/)
  });
  const parsed = paramsSchema.safeParse(req.params);
  if (!parsed.success) {
    return res.status(400).json({ message: 'Invalid month format. Use YYYY-MM' });
  }

  const [yearStr, monthStr] = parsed.data.month.split('-');
  const year = Number(yearStr);
  const month = Number(monthStr);
  const data = await getMonthDetail(String(req.userId), year, month);
  return res.json(data);
});

export default router;
