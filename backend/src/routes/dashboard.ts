import { Router } from 'express';
import { getDashboardSnapshot } from '../services/dashboard';

const router = Router();

router.get('/', async (req, res) => {
  const data = await getDashboardSnapshot(String(req.userId));
  return res.json(data);
});

export default router;
