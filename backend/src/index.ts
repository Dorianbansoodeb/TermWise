import express from 'express';
import cors from 'cors';
import { connectDb } from './config/db';
import { env } from './config/env';
import authRoutes from './routes/auth';
import profileRoutes from './routes/profile';
import planningRoutes from './routes/planning';
import transactionRoutes from './routes/transactions';
import dashboardRoutes from './routes/dashboard';
import { requireAuth } from './middleware/auth';

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/auth', authRoutes);
app.use('/profile', requireAuth, profileRoutes);
app.use('/planning', requireAuth, planningRoutes);
app.use('/transactions', requireAuth, transactionRoutes);
app.use('/dashboard', requireAuth, dashboardRoutes);

const bootstrap = async () => {
  await connectDb();
  app.listen(env.port, () => {
    console.log(`Backend listening on port ${env.port}`);
  });
};

bootstrap().catch((error) => {
  console.error('Failed to start backend:', error);
  process.exit(1);
});
