import { Router } from 'express';
import { z } from 'zod';
import { prisma, Role } from '../lib/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/rbac.js';
import { emitToUser } from '../lib/socket.js';

export const applicationsRouter = Router();

const asyncRoute =
  (fn: (req: any, res: any, next: any) => Promise<any>) =>
  (req: any, res: any, next: any) =>
    Promise.resolve(fn(req, res, next)).catch(next);

function cosineSimilarity(vecA: number[], vecB: number[]): number {
  let dotProduct = 0.0;
  let normA = 0.0;
  let normB = 0.0;
  const len = Math.min(vecA.length, vecB.length);
  for (let i = 0; i < len; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

const applicationStageEnum = z.enum(['APPLIED', 'SCREENED', 'INTERVIEW', 'OFFER', 'HIRED', 'REJECTED']);

const createApplicationSchema = z.object({
  jobId: z.string().uuid(),
});

const updateStageSchema = z.object({
  stage: z
    .string()
    .min(1)
    .transform((s) => s.trim().toUpperCase())
    .pipe(applicationStageEnum),
});

const applicationSelect = {
  id: true,
  jobId: true,
  applicantId: true,
  stage: true,
  matchScore: true,
  aiNotes: true,
  createdAt: true,
  updatedAt: true,
  applicant: { select: { id: true, email: true, name: true } },
} as const;

/**
 * @openapi
 * /applications/me:
 *   get:
 *     summary: List applications for the current authenticated user (candidate)
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: OK
 */
applicationsRouter.get(
  '/applications/me',
  requireAuth,
  asyncRoute(async (req, res) => {
    const userId = req.auth!.userId;

    const applications = await prisma.application.findMany({
      where: { applicantId: userId },
      include: {
        job: {
          select: { title: true, location: true, createdAt: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return res.json({ applications });
  }),
);

/**
 * @openapi
 * /applications:
...

/**
 * @openapi
 * /applications:
 *   post:
 *     summary: Apply to a job (job seeker)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               jobId: { type: string, format: uuid }
 *     responses:
 *       201:
 *         description: Created
 *       409:
 *         description: Already applied
 */
applicationsRouter.post(
  '/applications',
  requireAuth,
  asyncRoute(async (req, res) => {
    const parsed = createApplicationSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    const job = await prisma.job.findFirst({
      where: { id: parsed.data.jobId },
      select: { id: true, embedding: true, ownerId: true, title: true },
    });
    if (!job) return res.status(404).json({ error: 'Job not found' });

    const existing = await prisma.application.findFirst({
      where: { jobId: parsed.data.jobId, applicantId: req.auth!.userId },
      select: { id: true },
    });
    if (existing) return res.status(409).json({ error: 'Already applied to this job', applicationId: existing.id });

    // Look up applicant's resume embedding
    const candidate = await prisma.candidate.findFirst({
      where: { ownerId: req.auth!.userId },
      select: { embedding: true },
    });

    let matchScore: number | null = null;
    if (
      job.embedding &&
      Array.isArray(job.embedding) &&
      candidate &&
      candidate.embedding &&
      Array.isArray(candidate.embedding)
    ) {
      const score = cosineSimilarity(candidate.embedding as number[], job.embedding as number[]);
      matchScore = Math.round(score * 100);
    }

    const created = await prisma.application.create({
      data: {
        jobId: parsed.data.jobId,
        applicantId: req.auth!.userId,
        stage: 'APPLIED',
        matchScore: matchScore,
      },
      select: applicationSelect,
    });

    try {
      const applicantUser = await prisma.user.findUnique({
        where: { id: req.auth!.userId },
        select: { name: true, email: true },
      });
      const displayName = applicantUser?.name || applicantUser?.email || 'A candidate';

      // 1. Notify recruiter via socket
      emitToUser(job.ownerId, 'notification', {
        type: 'CANDIDATE_APPLIED',
        applicationId: created.id,
        jobId: job.id,
        jobTitle: job.title,
        candidateName: displayName,
      });

      // 2. Log in recruiter's dashboard activity feed
      await prisma.auditLog.create({
        data: {
          actorId: job.ownerId,
          action: 'CANDIDATE_APPLIED',
          entity: 'candidate',
          entityId: created.id, // Use application ID
          meta: {
            jobId: job.id,
            jobTitle: job.title,
            candidateName: displayName,
          },
        },
      });
    } catch (err) {
      console.error('Failed to dispatch application notification / audit log:', err);
    }

    return res.status(201).json({ application: created });
  }),
);

/**
 * @openapi
 * /applications/{id}/stage:
 *   patch:
 *     summary: Update application stage (recruiter)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               stage: { type: string, example: SCREENED }
 *     responses:
 *       200:
 *         description: OK
 */
applicationsRouter.patch(
  '/applications/:id/stage',
  requireAuth,
  requireRole([Role.RECRUITER, Role.HR_MANAGER, Role.ADMIN, Role.COMPANY]),
  asyncRoute(async (req, res) => {
    const parsed = updateStageSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    const updated = await prisma.application.update({
      where: { id: req.params.id },
      data: { stage: parsed.data.stage },
      select: applicationSelect,
    });

    emitToUser(updated.applicantId, 'notification', {
      type: 'STAGE_CHANGED',
      applicationId: updated.id,
      newStage: updated.stage,
    });

    return res.json({ application: updated });
  }),
);
