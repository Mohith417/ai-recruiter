import { Router } from 'express';
import { prisma, Role } from '../lib/prisma.js';
import { jwksManager } from '../lib/jwks.js';

export const authRouter = Router();

authRouter.get('/auth/v1/.well-known/jwks.json', async (req, res) => {
  try {
    const jwk = await jwksManager.getJwk();
    return res.json({ keys: [jwk] });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

authRouter.post('/auth/v1/signup', async (req, res) => {
  try {
    const { email, password, role } = req.body;
    if (!email) return res.status(400).json({ error: 'Email is required' });

    let user = await prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true, role: true },
    });

    if (!user) {
      user = await prisma.user.create({
        data: { 
          email, 
          role: (role === Role.JOB_SEEKER || role === Role.RECRUITER) ? role : Role.RECRUITER 
        },
        select: { id: true, email: true, role: true },
      });
    }

    const token = await jwksManager.signToken({
      sub: user.id,
      email: user.email,
      app_metadata: {
        provider: 'email',
        providers: ['email'],
      },
    }, user.email);

    return res.json({ token, user });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

authRouter.post('/auth/v1/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email) return res.status(400).json({ error: 'Email is required' });

    let user = await prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true, role: true },
    });

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = await jwksManager.signToken({
      sub: user.id,
      email: user.email,
      app_metadata: {
        provider: 'email',
        providers: ['email'],
      },
    }, user.email);

    return res.json({ token, user });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

authRouter.post('/auth/v1/google-login', async (req, res) => {
  try {
    const { email } = req.body;
    const resolvedEmail = email || 'google-candidate@local.test';

    let user = await prisma.user.findUnique({
      where: { email: resolvedEmail },
      select: { id: true, email: true, role: true },
    });

    if (!user) {
      user = await prisma.user.create({
        data: { email: resolvedEmail, role: Role.JOB_SEEKER },
        select: { id: true, email: true, role: true },
      });
    }

    const token = await jwksManager.signToken({
      sub: user.id,
      email: user.email,
      app_metadata: {
        provider: 'google',
        providers: ['google'],
      },
    }, user.email);

    return res.json({ token, user });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});
