import type { NextFunction, Request, Response } from 'express';
import { createRemoteJWKSet, jwtVerify, decodeProtectedHeader } from 'jose';
import { z } from 'zod';
import { prisma, Role } from '../lib/prisma.js';
import { jwksManager } from '../lib/jwks.js';

const bearerSchema = z.string().regex(/^Bearer\s+/i);

function getToken(req: Request): string | null {
  const h = req.header('authorization');
  if (!h) return null;
  if (!bearerSchema.safeParse(h).success) return null;
  return h.replace(/^Bearer\s+/i, '').trim();
}

// Supabase JWKS: `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`
function getJwks() {
  const supabaseUrl = process.env.SUPABASE_URL;
  if (!supabaseUrl) throw new Error('SUPABASE_URL is not set');
  return createRemoteJWKSet(new URL(`${supabaseUrl.replace(/\/$/, '')}/auth/v1/.well-known/jwks.json`));
}
export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const token = getToken(req);
    if (!token) return res.status(401).json({ error: 'Missing bearer token' });

    const audience = process.env.SUPABASE_JWT_AUD || undefined;

    const header = decodeProtectedHeader(token);
    let payload;
    if (header.kid === 'local-key-1') {
      const verifyKey = await jwksManager.getPublicKey();
      const resVal = await jwtVerify(token, verifyKey, { audience });
      payload = resVal.payload;
    } else {
      const verifyKey = getJwks();
      const resVal = await jwtVerify(token, verifyKey, { audience });
      payload = resVal.payload;
    }

    const userId = String(payload.sub ?? '');
    const email = String(payload.email ?? '');
    if (!userId || !email) return res.status(401).json({ error: 'Invalid token claims' });

    const appMetadata = (payload.app_metadata as Record<string, any>) || {};
    const provider = appMetadata.provider || (appMetadata.providers && appMetadata.providers[0]) || '';

    let user = await prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true, role: true },
    });

    if (!user) {
      const initialRole = provider === 'google' ? Role.JOB_SEEKER : Role.RECRUITER;
      user = await prisma.user.create({
        data: { email, role: initialRole },
        select: { id: true, email: true, role: true },
      });
    }

    req.auth = { userId: user.id, email: user.email, role: user.role };
    return next();
  } catch (e) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

export async function optionalAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const token = getToken(req);
    if (!token) return next();

    const audience = process.env.SUPABASE_JWT_AUD || undefined;

    const header = decodeProtectedHeader(token);
    let payload;
    if (header.kid === 'local-key-1') {
      const verifyKey = await jwksManager.getPublicKey();
      const resVal = await jwtVerify(token, verifyKey, { audience });
      payload = resVal.payload;
    } else {
      const verifyKey = getJwks();
      const resVal = await jwtVerify(token, verifyKey, { audience });
      payload = resVal.payload;
    }

    const userId = String(payload.sub ?? '');
    const email = String(payload.email ?? '');
    if (userId && email) {
      const appMetadata = (payload.app_metadata as Record<string, any>) || {};
      const provider = appMetadata.provider || (appMetadata.providers && appMetadata.providers[0]) || '';

      let user = await prisma.user.findUnique({
        where: { email },
        select: { id: true, email: true, role: true },
      });

      if (!user) {
        const initialRole = provider === 'google' ? Role.JOB_SEEKER : Role.RECRUITER;
        user = await prisma.user.create({
          data: { email, role: initialRole },
          select: { id: true, email: true, role: true },
        });
      }

      req.auth = { userId: user.id, email: user.email, role: user.role };
    }
  } catch (e) {
    console.warn('Optional auth failed:', (e as Error).message);
  }
  return next();
}

