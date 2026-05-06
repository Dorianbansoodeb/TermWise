import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { env } from '../config/env';

type JwtPayload = { sub: string };

export const requireAuth = (req: Request, res: Response, next: NextFunction): void => {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ message: 'Missing token' });
    return;
  }

  const token = header.replace('Bearer ', '');
  try {
    const payload = jwt.verify(token, env.jwtSecret) as JwtPayload;
    req.userId = new mongoose.Types.ObjectId(payload.sub);
    next();
  } catch {
    res.status(401).json({ message: 'Invalid token' });
  }
};
