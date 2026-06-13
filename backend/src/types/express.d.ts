import type { Role } from '../lib/prisma.js';

declare global {
  namespace Express {
    interface Request {
      auth?: {
        userId: string;
        email: string;
        role: Role;
      };
    }
  }
}

export {};
