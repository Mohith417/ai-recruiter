import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { requireAuth } from '../middleware/auth.js';

export const interviewsRouter = Router();

const asyncRoute =
  (fn: (req: any, res: any, next: any) => Promise<any>) =>
  (req: any, res: any, next: any) =>
    Promise.resolve(fn(req, res, next)).catch(next);

const interviewStatusEnum = z.enum(['SCHEDULED', 'COMPLETED', 'CANCELLED']);

const createInterviewSchema = z.object({
  candidateId: z.string().uuid(),
  jobId: z.string().uuid(),
  scheduledAt: z.string().datetime(),
  durationMinutes: z.number().int().positive().default(30),
  interviewerName: z.string().optional(),
  notes: z.string().optional(),
});

const updateInterviewSchema = z.object({
  scheduledAt: z.string().datetime().optional(),
  durationMinutes: z.number().int().positive().optional(),
  interviewerName: z.string().optional(),
  notes: z.string().optional(),
  status: interviewStatusEnum.optional(),
});

const interviewSelect = {
  id: true,
  candidateId: true,
  jobId: true,
  ownerId: true,
  scheduledAt: true,
  durationMinutes: true,
  interviewerName: true,
  notes: true,
  status: true,
  createdAt: true,
  updatedAt: true,
  candidate: {
    select: {
      name: true,
      email: true,
    },
  },
  job: {
    select: {
      title: true,
    },
  },
} as const;

/**
 * @openapi
 * /interviews:
 *   get:
 *     summary: List interviews (owned by current user)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: candidateId
 *         required: false
 *         schema: { type: string, format: uuid }
 *       - in: query
 *         name: jobId
 *         required: false
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: OK
 */
interviewsRouter.get(
  '/interviews',
  requireAuth,
  asyncRoute(async (req, res) => {
    const candidateId = typeof req.query.candidateId === 'string' ? req.query.candidateId : undefined;
    const rawJobId = typeof req.query.jobId === 'string' ? req.query.jobId.trim() : undefined;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    const jobId = (rawJobId && uuidRegex.test(rawJobId)) ? rawJobId : undefined;

    const items = await prisma.interview.findMany({
      where: {
        ownerId: req.auth!.userId,
        ...(candidateId ? { candidateId } : {}),
        ...(jobId ? { jobId } : {}),
      },
      orderBy: { scheduledAt: 'asc' },
      select: interviewSelect,
    });

    return res.json({ interviews: items });
  })
);

/**
 * @openapi
 * /interviews:
 *   post:
 *     summary: Create an interview
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [candidateId, jobId, scheduledAt]
 *             properties:
 *               candidateId: { type: string, format: uuid }
 *               jobId: { type: string, format: uuid }
 *               scheduledAt: { type: string, format: date-time }
 *               durationMinutes: { type: integer, default: 30 }
 *               interviewerName: { type: string }
 *               notes: { type: string }
 *     responses:
 *       201:
 *         description: Created
 */
interviewsRouter.post(
  '/interviews',
  requireAuth,
  asyncRoute(async (req, res) => {
    const parsed = createInterviewSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    const candidate = await prisma.candidate.findFirst({
      where: { id: parsed.data.candidateId, ownerId: req.auth!.userId },
    });
    if (!candidate) return res.status(404).json({ error: 'Candidate not found' });

    const job = await prisma.job.findFirst({
      where: { id: parsed.data.jobId },
    });
    if (!job) return res.status(404).json({ error: 'Job not found' });

    const created = await prisma.interview.create({
      data: {
        ownerId: req.auth!.userId,
        candidateId: parsed.data.candidateId,
        jobId: parsed.data.jobId,
        scheduledAt: new Date(parsed.data.scheduledAt),
        durationMinutes: parsed.data.durationMinutes,
        interviewerName: parsed.data.interviewerName ?? null,
        notes: parsed.data.notes ?? null,
        status: 'SCHEDULED',
      },
      select: interviewSelect,
    });

    return res.status(201).json({ interview: created });
  })
);

/**
 * @openapi
 * /interviews/{id}:
 *   patch:
 *     summary: Update an interview
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
 *               scheduledAt: { type: string, format: date-time }
 *               durationMinutes: { type: integer }
 *               interviewerName: { type: string }
 *               notes: { type: string }
 *               status: { type: string, enum: [SCHEDULED, COMPLETED, CANCELLED] }
 *     responses:
 *       200:
 *         description: OK
 */
interviewsRouter.patch(
  '/interviews/:id',
  requireAuth,
  asyncRoute(async (req, res) => {
    const parsed = updateInterviewSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    const existing = await prisma.interview.findFirst({
      where: { id: req.params.id, ownerId: req.auth!.userId },
    });
    if (!existing) return res.status(404).json({ error: 'Interview not found' });

    const updated = await prisma.interview.update({
      where: { id: req.params.id },
      data: {
        ...(parsed.data.scheduledAt && { scheduledAt: new Date(parsed.data.scheduledAt) }),
        ...(parsed.data.durationMinutes !== undefined && { durationMinutes: parsed.data.durationMinutes }),
        ...(parsed.data.interviewerName !== undefined && { interviewerName: parsed.data.interviewerName }),
        ...(parsed.data.notes !== undefined && { notes: parsed.data.notes }),
        ...(parsed.data.status && { status: parsed.data.status }),
      },
      select: interviewSelect,
    });

    return res.json({ interview: updated });
  })
);

/**
 * @openapi
 * /interviews/{id}:
 *   delete:
 *     summary: Cancel/Delete an interview
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: OK
 */
interviewsRouter.delete(
  '/interviews/:id',
  requireAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.interview.findFirst({
      where: { id: req.params.id, ownerId: req.auth!.userId },
    });
    if (!existing) return res.status(404).json({ error: 'Interview not found' });

    await prisma.interview.delete({
      where: { id: req.params.id },
    });

    return res.json({ ok: true });
  })
);
