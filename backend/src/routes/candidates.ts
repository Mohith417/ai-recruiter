import { Router } from 'express';
import { z } from 'zod';

import { prisma, Role } from '../lib/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/rbac.js';
import { emitToUser } from '../lib/socket.js';

export const candidatesRouter = Router();

const recruiterRoles = [Role.RECRUITER, Role.HR_MANAGER, Role.ADMIN, Role.COMPANY];

// Express v4 does not automatically catch async errors.
// This wrapper forwards rejected promises to the error middleware.
const asyncRoute =
  (fn: (req: any, res: any, next: any) => Promise<any>) =>
  (req: any, res: any, next: any) =>
    Promise.resolve(fn(req, res, next)).catch(next);

const candidateStatusEnum = z.enum([
  'APPLIED',
  'PARSED',
  'SCREENED',
  'INTERVIEW',
  'OFFER',
  'HIRED',
  'REJECTED',
]);

const createCandidateSchema = z.object({
  name: z.string().min(1).optional(),
  email: z.string().email().optional(),
  jobId: z.string().uuid().optional(),
  resumeFileUrl: z
    .string()
    .transform((s) => s.replace(/[`'"]/g, '').trim())
    .optional()
    .transform((s) => ((s?.length ?? 0) === 0 ? undefined : s))
    .pipe(z.string().url().optional()),
  status: z
    .string()
    .min(1)
    .transform((s) => s.trim().toUpperCase())
    .pipe(candidateStatusEnum)
    .optional(),
});

const candidateSelect = {
  id: true,
  name: true,
  email: true,
  resumeFileUrl: true,
  jobId: true,
  status: true,
  cultureFitScore: true,
  cultureFitRationale: true,
  createdAt: true,
  updatedAt: true,
} as const;

const updateCandidateStatusSchema = z.object({
  status: z.string().min(1).transform((s) => s.trim().toUpperCase()),
});

const updateCandidateSchema = z
  .object({
    name: z.string().min(1).optional(),
    email: z.string().email().optional(),
    resumeFileUrl: z
      .string()
      .transform((s) => s.replace(/[`'"]/g, '').trim())
      .optional()
      .transform((s) => ((s?.length ?? 0) === 0 ? undefined : s))
      .pipe(z.string().url().optional()),
  })
  .refine((v) => v.name || v.email || v.resumeFileUrl, {
    message: 'At least one field is required',
  });

/**
 * @openapi
 * /candidates:
 *   get:
 *     summary: List candidates (owned by current user) and direct applications
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: OK
 */
candidatesRouter.get(
  '/candidates',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const rawJobId = typeof req.query.jobId === 'string' ? req.query.jobId.trim() : undefined;
    
    // Validate UUID format to prevent Prisma errors
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    const jobId = (rawJobId && uuidRegex.test(rawJobId)) ? rawJobId : undefined;
    
    const userId = req.auth!.userId;

    // 1. Fetch Candidates (manual/parsed)
    const candidates = await prisma.candidate.findMany({
      where: { ownerId: userId, ...(jobId ? { jobId } : {}) },
      orderBy: { createdAt: 'desc' },
      select: candidateSelect,
    });

    // 2. Fetch Applications (direct applicants)
    // If no jobId is provided, we fetch applications for all jobs owned by this recruiter
    const applications = await prisma.application.findMany({
      where: {
        ...(jobId ? { jobId } : { job: { ownerId: userId } }),
      },
      include: {
        applicant: {
          select: { name: true, email: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    // 3. Map applications to candidate schema
    const mappedApplications = applications.map((app) => ({
      id: app.id,
      name: app.applicant.name || app.applicant.email,
      email: app.applicant.email,
      resumeFileUrl: null,
      jobId: app.jobId,
      status: app.stage,
      createdAt: app.createdAt,
      updatedAt: app.updatedAt,
      isApplication: true,
    }));

    // Combine and sort by date
    const all = [...candidates, ...mappedApplications].sort(
      (a, b) => new Date(b.createdAt as any).getTime() - new Date(a.createdAt as any).getTime()
    );

    return res.json({ candidates: all });
  }),
);

/**
 * @openapi
 * /candidates/search:
 *   get:
 *     summary: Search candidates semantically by query (using embeddings similarity)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: q
 *         required: true
 *         schema: { type: string }
 *       - in: query
 *         name: jobId
 *         required: false
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: OK
 */
candidatesRouter.get(
  '/candidates/search',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    const rawJobId = typeof req.query.jobId === 'string' ? req.query.jobId.trim() : undefined;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    const jobId = (rawJobId && uuidRegex.test(rawJobId)) ? rawJobId : undefined;

    if (!q) {
      return res.status(400).json({ error: 'Search query parameter "q" is required' });
    }

    // 1. Get query embedding from ML service
    const mlServiceUrl = process.env.ML_SERVICE_URL || 'http://ml_service:8000';
    let queryEmbedding: number[] | null = null;
    try {
      const response = await fetch(`${mlServiceUrl}/embeddings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ texts: [q] }),
      });
      if (response.ok) {
        const resData = await response.json() as any;
        if (resData.vectors && resData.vectors.length > 0) {
          queryEmbedding = resData.vectors[0];
        }
      } else {
        console.warn(`ML service embeddings request failed: ${response.statusText}`);
      }
    } catch (err) {
      console.warn(`Failed to connect to ML service at ${mlServiceUrl}: ${(err as Error).message}`);
    }

    // 2. Query candidates using pgvector similarity or fallback keyword matching
    let results: any[] = [];
    if (queryEmbedding) {
      const vectorStr = `[${queryEmbedding.join(',')}]`;
      try {
        const vectorResults: any[] = await prisma.$queryRawUnsafe(
          `SELECT id, name, email, "resumeFileUrl", "jobId", status, "createdAt", "updatedAt", "resumeText",
                  (1.0 - (CAST(embedding::text AS vector) <=> CAST($1 AS vector)))::float AS score
           FROM "Candidate"
           WHERE "ownerId" = $2 AND (${jobId ? '"jobId" = $3' : '1=1'}) AND embedding IS NOT NULL`,
          ...[vectorStr, req.auth!.userId, ...(jobId ? [jobId] : [])]
        );

        // Fetch candidates for keyword-matching fallback
        const allUserCandidates = await prisma.candidate.findMany({
          where: {
            ownerId: req.auth!.userId,
            ...(jobId ? { jobId } : {}),
          },
          select: {
            id: true,
            name: true,
            email: true,
            resumeFileUrl: true,
            jobId: true,
            status: true,
            createdAt: true,
            updatedAt: true,
            resumeText: true,
            embedding: true,
          },
        });
        const textCandidates = allUserCandidates.filter((c) => !c.embedding);

        const keywordResults = textCandidates
          .map((candidate) => {
            let score = 0.0;
            if (candidate.resumeText) {
              score = keywordSimilarity(q, candidate.resumeText);
            } else if (candidate.name && candidate.name.toLowerCase().includes(q.toLowerCase())) {
              score = 0.3;
            }
            return { ...candidate, score };
          })
          .filter((c) => c.score > 0.05);

        results = [...vectorResults, ...keywordResults]
          .filter((c) => c.score > 0.05)
          .sort((a, b) => b.score - a.score);
      } catch (err) {
        console.warn('pgvector search failed or extension not loaded, falling back to full in-memory:', err);
        const allCandidates = await prisma.candidate.findMany({
          where: {
            ownerId: req.auth!.userId,
            ...(jobId ? { jobId } : {}),
          },
        });
        results = allCandidates
          .map((c) => {
            let score = 0.0;
            if (c.embedding && Array.isArray(c.embedding)) {
              score = cosineSimilarity(queryEmbedding!, c.embedding as number[]);
            } else if (c.resumeText) {
              score = keywordSimilarity(q, c.resumeText);
            }
            return {
              id: c.id,
              name: c.name,
              email: c.email,
              resumeFileUrl: c.resumeFileUrl,
              jobId: c.jobId,
              status: c.status,
              createdAt: c.createdAt,
              updatedAt: c.updatedAt,
              resumeText: c.resumeText,
              score,
            };
          })
          .filter((c) => c.score > 0.05)
          .sort((a, b) => b.score - a.score);
      }
    } else {
      const candidates = await prisma.candidate.findMany({
        where: {
          ownerId: req.auth!.userId,
          ...(jobId ? { jobId } : {}),
        },
        select: {
          id: true,
          name: true,
          email: true,
          resumeFileUrl: true,
          jobId: true,
          status: true,
          createdAt: true,
          updatedAt: true,
          resumeText: true,
        },
      });
      results = candidates
        .map((candidate) => {
          let score = 0.0;
          if (candidate.resumeText) {
            score = keywordSimilarity(q, candidate.resumeText);
          } else if (candidate.name && candidate.name.toLowerCase().includes(q.toLowerCase())) {
            score = 0.5;
          }
          return { ...candidate, score };
        })
        .filter((c) => c.score > 0)
        .sort((a, b) => b.score - a.score);
    }

    const sanitizedResults = results.map(({ embedding, resumeText, ...rest }) => rest);
    return res.json({ candidates: sanitizedResults });
  }),
);

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

function keywordSimilarity(query: string, text: string): number {
  const qWords = query.toLowerCase().split(/\s+/).filter(Boolean);
  const textLower = text.toLowerCase();
  let matches = 0;
  for (const word of qWords) {
    if (textLower.includes(word)) matches++;
  }
  return qWords.length > 0 ? matches / qWords.length : 0.0;
}

/**
 * @openapi
 * /candidates/{id}:
 *   get:
 *     summary: Get candidate or application by id
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: OK
 *       404:
 *         description: Not found
 */
candidatesRouter.get(
  '/candidates/:id',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const userId = req.auth!.userId;
    const { id } = req.params;

    // 1. Try manual Candidate
    const candidate = await prisma.candidate.findFirst({
      where: { id, ownerId: userId },
      select: candidateSelect,
    });

    if (candidate) return res.json({ candidate });

    // 2. Try Application
    const application = await prisma.application.findFirst({
      where: { id, job: { ownerId: userId } },
      include: {
        applicant: { select: { id: true, email: true, name: true, avatarUrl: true } },
      },
    });

    if (application) {
      // Notify candidate that a recruiter is viewing their application
      if (application.applicantId !== userId) {
        const job = await prisma.job.findUnique({
          where: { id: application.jobId },
          select: { title: true },
        });
        emitToUser(application.applicantId, 'notification', {
          type: 'APPLICATION_VIEWED',
          applicationId: application.id,
          jobTitle: job?.title || 'a job',
        });
      }

      return res.json({
        candidate: {
          id: application.id,
          name: application.applicant.name || application.applicant.email,
          email: application.applicant.email,
          resumeFileUrl: null, // User applications might not have a public resume URL in this schema yet
          jobId: application.jobId,
          status: application.stage,
          matchScore: application.matchScore,
          aiNotes: application.aiNotes,
          createdAt: application.createdAt,
          updatedAt: application.updatedAt,
          isApplication: true,
        },
      });
    }

    return res.status(404).json({ error: 'Candidate or Application not found' });
  }),
);

/**
 * @openapi
 * /candidates/{id}:
 *   delete:
 *     summary: Delete candidate by id
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: OK
 *       404:
 *         description: Not found
 */
candidatesRouter.delete(
  '/candidates/:id',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
  const deleted = await prisma.candidate.deleteMany({
    where: { id: req.params.id, ownerId: req.auth!.userId },
  });
  if (deleted.count === 0) return res.status(404).json({ error: 'Candidate not found' });
  return res.json({ ok: true });
  }),
);

/**
 * @openapi
 * /candidates/{id}:
 *   patch:
 *     summary: Update candidate fields (name/email/resumeFileUrl)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name: { type: string }
 *               email: { type: string }
 *               resumeFileUrl: { type: string }
 *     responses:
 *       200:
 *         description: OK
 *       400:
 *         description: Bad request
 *       404:
 *         description: Not found
 */
candidatesRouter.patch(
  '/candidates/:id',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
  const parsed = updateCandidateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const updated = await prisma.candidate.updateMany({
    where: { id: req.params.id, ownerId: req.auth!.userId },
    data: {
      name: parsed.data.name,
      email: parsed.data.email,
      resumeFileUrl: parsed.data.resumeFileUrl ?? null,
    },
  });

  if (updated.count === 0) return res.status(404).json({ error: 'Candidate not found' });

  const candidate = await prisma.candidate.findFirst({
    where: { id: req.params.id, ownerId: req.auth!.userId },
    select: candidateSelect,
  });

  return res.json({ candidate });
  }),
);

/**
 * @openapi
 * /candidates:
 *   post:
 *     summary: Create a candidate
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name: { type: string }
 *               email: { type: string }
 *               resumeFileUrl: { type: string }
 *               status: { type: string, example: APPLIED }
 *     responses:
 *       201:
 *         description: Created
 */
candidatesRouter.post(
  '/candidates',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
  const parsed = createCandidateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  if (parsed.data.jobId) {
    const job = await prisma.job.findFirst({
      // Allow linking to an existing job even if it wasn't created by this dev user.
      // (Jobs are currently public in Phase 1.)
      where: { id: parsed.data.jobId },
      select: { id: true },
    });
    if (!job) return res.status(404).json({ error: 'Job not found' });
  }

  const created = await prisma.candidate.create({
    data: {
      ownerId: req.auth!.userId,
      name: parsed.data.name,
      email: parsed.data.email,
      resumeFileUrl: parsed.data.resumeFileUrl ?? null,
      status: parsed.data.status ?? 'PARSED',
      jobId: parsed.data.jobId ?? null,
    },
    select: candidateSelect,
  });

  await prisma.auditLog.create({
    data: {
      actorId: req.auth!.userId,
      action: 'CANDIDATE_CREATED',
      entity: 'candidate',
      entityId: created.id,
      meta: {
        name: created.name,
        email: created.email,
        jobId: created.jobId,
        status: created.status,
      },
    },
  });

  return res.status(201).json({ candidate: created });
  }),
);

/**
 * @openapi
 * /candidates/{id}/status:
 *   patch:
 *     summary: Update candidate status or application stage
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               status: { type: string, example: SCREENED }
 *     responses:
 *       200:
 *         description: OK
 *       404:
 *         description: Not found
 */
candidatesRouter.patch(
  '/candidates/:id/status',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const parsed = updateCandidateStatusSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    const userId = req.auth!.userId;
    const { id } = req.params;
    const { status } = parsed.data;

    // 1. Try to update manual Candidate
    const candidateUpdate = await prisma.candidate.updateMany({
      where: { id, ownerId: userId },
      data: { status },
    });

    if (candidateUpdate.count > 0) {
      const candidate = await prisma.candidate.findFirst({
        where: { id, ownerId: userId },
        select: candidateSelect,
      });
      return res.json({ candidate });
    }

    // 2. Try to update Application
    // We check if the application belongs to a job owned by this recruiter
    const application = await prisma.application.findFirst({
      where: { id, job: { ownerId: userId } },
      include: {
        applicant: { select: { name: true, email: true } },
      },
    });

    if (application) {
      const updatedApp = await prisma.application.update({
        where: { id },
        data: { stage: status },
      });
      
      // Notify candidate about the status update
      emitToUser(application.applicantId, 'notification', {
        type: 'STAGE_CHANGED',
        applicationId: updatedApp.id,
        newStage: updatedApp.stage,
        jobId: updatedApp.jobId,
      });

      // Map back to unified candidate schema for frontend consistency
      return res.json({
        candidate: {
          id: updatedApp.id,
          name: application.applicant.name || application.applicant.email,
          email: application.applicant.email,
          status: updatedApp.stage,
          jobId: updatedApp.jobId,
          createdAt: updatedApp.createdAt,
          updatedAt: updatedApp.updatedAt,
          isApplication: true,
        },
      });
    }

    return res.status(404).json({ error: 'Candidate or Application not found' });
  }),
);

const evaluateCultureFitSchema = z.object({
  companyValues: z.string().min(3),
  interviewNotes: z.string().min(3),
});

/**
 * @openapi
 * /candidates/{id}/culture-fit:
 *   post:
 *     summary: Evaluate candidate culture fit
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               companyValues: { type: string }
 *               interviewNotes: { type: string }
 *     responses:
 *       200:
 *         description: OK
 *       404:
 *         description: Candidate not found
 */
candidatesRouter.post(
  '/candidates/:id/culture-fit',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const parsed = evaluateCultureFitSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    let targetType: 'CANDIDATE' | 'APPLICATION' = 'CANDIDATE';
    let target = await prisma.candidate.findFirst({
      where: { id: req.params.id, ownerId: req.auth!.userId },
      select: { id: true },
    });

    if (!target) {
      target = await prisma.application.findFirst({
        where: { id: req.params.id, job: { ownerId: req.auth!.userId } },
        select: { id: true },
      }) as any;
      if (target) targetType = 'APPLICATION';
    }

    if (!target) return res.status(404).json({ error: 'Candidate or Application not found' });

    const mlServiceUrl = process.env.ML_SERVICE_URL || 'http://ml_service:8000';
    let score = null;
    let rationale = null;

    try {
      const response = await fetch(`${mlServiceUrl}/culture-fit/score`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          company_values: parsed.data.companyValues,
          interview_notes: parsed.data.interviewNotes,
        }),
      });

      if (response.ok) {
        const resData = await response.json() as any;
        score = Math.round(resData.score * 100);
        rationale = resData.rationale;
      }
    } catch (err) {
      console.warn(`Failed to connect to ML service at ${mlServiceUrl}: ${(err as Error).message}`);
      return res.status(502).json({ error: 'Failed to communicate with the ML service' });
    }

    let result;
    if (targetType === 'CANDIDATE') {
      result = await prisma.candidate.update({
        where: { id: req.params.id },
        data: {
          cultureFitScore: score,
          cultureFitRationale: rationale,
        },
        select: candidateSelect,
      } as any);
    } else {
      const updatedApp = await prisma.application.update({
        where: { id: req.params.id },
        data: {
          matchScore: score, // Map score to matchScore for applications
          aiNotes: rationale, // Map rationale to aiNotes for applications
        },
      });
      // Map back to unified candidate schema
      const fullApp = await prisma.application.findUnique({
        where: { id: updatedApp.id },
        include: { applicant: { select: { name: true, email: true } } },
      });
      result = {
        id: updatedApp.id,
        name: fullApp?.applicant.name || fullApp?.applicant.email,
        email: fullApp?.applicant.email,
        status: updatedApp.stage,
        matchScore: updatedApp.matchScore,
        aiNotes: updatedApp.aiNotes,
        isApplication: true,
      };
    }

    return res.json({ candidate: result });
  }),
);
