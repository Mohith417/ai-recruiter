import { Router } from 'express';
import fs from 'fs';
import path from 'path';

import { requireAuth } from '../middleware/auth.js';

export const meRouter = Router();

/**
 * @openapi
 * /me:
 *   get:
 *     summary: Get current user (resolved from Supabase JWT -> DB user)
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User info
 */
import { z } from 'zod';
import { prisma, Role } from '../lib/prisma.js';

meRouter.get('/me', requireAuth, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.auth!.userId },
      select: {
        id: true,
        email: true,
        name: true,
        avatarUrl: true,
        role: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!user) return res.status(404).json({ error: 'User not found' });
    return res.json({ user });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

const updateMeSchema = z.object({
  role: z.nativeEnum(Role).optional(),
  name: z.string().min(1).optional(),
  avatarUrl: z.string().optional(),
});

/**
 * @openapi
 * /me:
 *   patch:
 *     summary: Update current user profile (name, avatar, role)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               role:
 *                 type: string
 *                 enum: [JOB_SEEKER, RECRUITER, HR_MANAGER, INTERVIEWER, ADMIN, COMPANY]
 *               name:
 *                 type: string
 *               avatarUrl:
 *                 type: string
 *     responses:
 *       200:
 *         description: User updated
 */
meRouter.patch('/me', requireAuth, async (req, res) => {
  try {
    const parsed = updateMeSchema.parse(req.body);
    const updated = await prisma.user.update({
      where: { id: req.auth!.userId },
      data: {
        ...(parsed.role && { role: parsed.role }),
        ...(parsed.name !== undefined && { name: parsed.name }),
        ...(parsed.avatarUrl !== undefined && { avatarUrl: parsed.avatarUrl }),
      },
    });
    return res.json({ user: updated });
  } catch (err: any) {
    return res.status(400).json({ error: err.message });
  }
});

/**
 * @openapi
 * /upload:
 *   post:
 *     summary: Upload user avatar in base64 format
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               fileName:
 *                 type: string
 *               base64:
 *                 type: string
 *     responses:
 *       200:
 *         description: Avatar uploaded successfully
 */
meRouter.post('/upload', requireAuth, async (req, res) => {
  try {
    const { fileName, base64 } = req.body;
    if (!fileName || !base64) {
      return res.status(400).json({ error: 'Missing fileName or base64 data' });
    }

    const buffer = Buffer.from(base64, 'base64');
    const uploadDir = path.join(process.cwd(), '../.uploads');
    
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }

    const sanitizedName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
    const uniqueName = `${Date.now()}_${sanitizedName}`;
    const filePath = path.join(uploadDir, uniqueName);
    
    await fs.promises.writeFile(filePath, buffer);

    const baseUrl = process.env.API_BASE_URL ?? 'http://localhost:4000';
    return res.json({ url: `${baseUrl.replace(/\/$/, '')}/uploads/${uniqueName}` });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

