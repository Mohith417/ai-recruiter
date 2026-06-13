import type { NextFunction, Request, Response } from 'express';
import type { Role } from '@prisma/client';

export function requireRole(allowed: Role[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const role = req.auth?.role;
    if (!role) return res.status(401).json({ error: 'Unauthorized' });
    if (!allowed.includes(role)) return res.status(403).json({ error: 'Forbidden' });
    return next();
  };
}
