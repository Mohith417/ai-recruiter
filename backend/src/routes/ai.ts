import { Router } from 'express';
import { z } from 'zod';

import { prisma } from '../lib/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { aiQueue } from '../queues/ai.js';

export const aiRouter = Router();

const resumeParseSchema = z.object({
  // Swagger / PowerShell users sometimes accidentally wrap URLs with backticks.
  // We sanitize those here so the endpoint is more forgiving in dev.
  resumeFileUrl: z.preprocess(
    (v) => (typeof v === 'string' ? v.replace(/[`'"]/g, '').trim() : v),
    z.string().url(),
  ),
  jobId: z.string().uuid().optional(),
});

/**
 * @openapi
 * /ai/resume/parse:
 *   post:
 *     summary: Enqueue resume parsing (async via BullMQ)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               resumeFileUrl: { type: string }
 *     responses:
 *       202:
 *         description: Accepted
 */
aiRouter.post('/ai/resume/parse', requireAuth, async (req, res) => {
  const parsed = resumeParseSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  if (parsed.data.jobId) {
    const jobRow = await prisma.job.findFirst({
      where: { id: parsed.data.jobId },
      select: { id: true },
    });
    if (!jobRow) return res.status(404).json({ error: 'Job not found' });
  }

  const job = await aiQueue.add('resume.parse', {
    userId: req.auth!.userId,
    resumeFileUrl: parsed.data.resumeFileUrl,
    jobId: parsed.data.jobId,
  });

  await prisma.auditLog.create({
    data: {
      actorId: req.auth!.userId,
      action: 'AI_RESUME_PARSE_ENQUEUED',
      entity: 'ai_job',
      entityId: String(job.id),
      meta: {
        queueJobId: job.id,
        resumeFileUrl: parsed.data.resumeFileUrl,
        jobId: parsed.data.jobId ?? null,
      },
    },
  });

  return res.status(202).json({ jobId: job.id });
});
