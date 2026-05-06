import dotenv from 'dotenv';

dotenv.config();

export const env = {
  port: Number(process.env.PORT ?? 4000),
  mongoUri: process.env.MONGODB_URI ?? '',
  jwtSecret: process.env.JWT_SECRET ?? ''
};

if (!env.mongoUri || !env.jwtSecret) {
  throw new Error('Missing required env vars: MONGODB_URI, JWT_SECRET');
}
