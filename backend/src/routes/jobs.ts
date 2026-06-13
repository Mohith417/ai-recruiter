import { Router } from 'express';
import { z } from 'zod';
import { prisma, Role } from '../lib/prisma.js';
import { requireAuth, optionalAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/rbac.js';

export const jobsRouter = Router();

const createJobSchema = z.object({
  title: z.string().min(3),
  description: z.string().min(10),
  location: z.string().optional(),
  salaryMin: z.number().int().nonnegative().optional(),
  salaryMax: z.number().int().nonnegative().optional(),
});

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

/**
 * @openapi
 * /jobs:
 *   get:
 *     summary: List jobs (public)
 *     responses:
 *       200:
 *         description: OK
 */
jobsRouter.get('/jobs', optionalAuth, async (req, res) => {
  let userEmbedding: number[] | null = null;
  if (req.auth) {
    const candidate = await prisma.candidate.findFirst({
      where: { ownerId: req.auth.userId },
      select: { embedding: true },
    });
    if (candidate && candidate.embedding && Array.isArray(candidate.embedding)) {
      userEmbedding = candidate.embedding as number[];
    }
  }

  const jobs = await prisma.job.findMany({
    orderBy: { createdAt: 'desc' },
    take: 50,
    select: {
      id: true,
      title: true,
      description: true,
      location: true,
      salaryMin: true,
      salaryMax: true,
      createdAt: true,
      companyId: true,
      embedding: true,
    },
  });

  const results = jobs.map((job) => {
    let matchScore: number | null = null;
    if (userEmbedding && job.embedding && Array.isArray(job.embedding)) {
      const score = cosineSimilarity(userEmbedding, job.embedding as number[]);
      matchScore = Math.round(score * 100);
    }
    const { embedding, ...rest } = job;
    return {
      ...rest,
      matchScore,
    };
  });

  return res.json({ jobs: results });
});

/**
 * @openapi
 * /jobs/{id}:
 *   get:
 *     summary: Get a job by id
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: OK
 *       404:
 *         description: Not found
 */
jobsRouter.get('/jobs/:id', optionalAuth, async (req, res) => {
  const job = await prisma.job.findFirst({
    where: { id: req.params.id },
    select: {
      id: true,
      title: true,
      description: true,
      location: true,
      salaryMin: true,
      salaryMax: true,
      createdAt: true,
      companyId: true,
      embedding: true,
    },
  });
  if (!job) return res.status(404).json({ error: 'Job not found' });

  let matchScore: number | null = null;
  if (req.auth && job.embedding && Array.isArray(job.embedding)) {
    const candidate = await prisma.candidate.findFirst({
      where: { ownerId: req.auth.userId },
      select: { embedding: true },
    });
    if (candidate && candidate.embedding && Array.isArray(candidate.embedding)) {
      const score = cosineSimilarity(candidate.embedding as number[], job.embedding as number[]);
      matchScore = Math.round(score * 100);
    }
  }

  const { embedding, ...rest } = job;
  return res.json({
    job: {
      ...rest,
      matchScore,
    },
  });
});

/**
 * @openapi
 * /jobs:
 *   post:
 *     summary: Create a job (recruiter/hr/admin/company)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title: { type: string }
 *               description: { type: string }
 *               location: { type: string }
 *               salaryMin: { type: integer }
 *               salaryMax: { type: integer }
 *     responses:
 *       201:
 *         description: Created
 */
jobsRouter.post(
  '/jobs',
  requireAuth,
  requireRole([Role.RECRUITER, Role.HR_MANAGER, Role.ADMIN, Role.COMPANY]),
  async (req, res) => {
    const parsed = createJobSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    // Generate job embedding using FastAPI ML service
    const mlServiceUrl = process.env.ML_SERVICE_URL || 'http://ml_service:8000';
    let jobEmbedding: number[] | null = null;
    try {
      const response = await fetch(`${mlServiceUrl}/embeddings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ texts: [`${parsed.data.title}\n${parsed.data.description}`] }),
      });
      if (response.ok) {
        const resData = await response.json() as any;
        if (resData.vectors && resData.vectors.length > 0) {
          jobEmbedding = resData.vectors[0];
        }
      }
    } catch (err) {
      console.warn(`Failed to generate job embedding: ${(err as Error).message}`);
    }

    const job = await prisma.job.create({
      data: {
        ...parsed.data,
        ownerId: req.auth!.userId,
        companyId: null,
        embedding: jobEmbedding ? (jobEmbedding as any) : undefined,
      },
    });

    await prisma.auditLog.create({
      data: {
        actorId: req.auth!.userId,
        action: 'JOB_CREATED',
        entity: 'job',
        entityId: job.id,
        meta: {
          title: job.title,
          location: job.location,
        },
      },
    });

    return res.status(201).json({ job });
  },
);
