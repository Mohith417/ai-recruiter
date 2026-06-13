import { Router } from 'express';

import { prisma, Role } from '../lib/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/rbac.js';

export const dashboardRouter = Router();

// Express v4 does not automatically catch async errors.
// This wrapper forwards rejected promises to the error middleware.
const asyncRoute =
  (fn: (req: any, res: any, next: any) => Promise<any>) =>
  (req: any, res: any, next: any) =>
    Promise.resolve(fn(req, res, next)).catch(next);

const recruiterRoles = [Role.RECRUITER, Role.HR_MANAGER, Role.ADMIN, Role.COMPANY];

/**
 * @openapi
 * /dashboard/stats:
 *   get:
 *     summary: Get dashboard statistics for the current user
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: OK
 */
dashboardRouter.get(
  '/dashboard/stats',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const userId = req.auth!.userId;
    const rawJobId = typeof req.query.jobId === 'string' ? req.query.jobId.trim() : undefined;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    const jobId = (rawJobId && uuidRegex.test(rawJobId)) ? rawJobId : undefined;
    const startDate = typeof req.query.startDate === 'string' ? new Date(req.query.startDate) : undefined;
    const endDate = typeof req.query.endDate === 'string' ? new Date(req.query.endDate) : undefined;
    if (startDate) startDate.setHours(0, 0, 0, 0);
    if (endDate) endDate.setHours(23, 59, 59, 999);

    const candWhere: any = {
      ownerId: userId,
      ...(jobId ? { jobId } : {}),
      ...(startDate || endDate ? {
        createdAt: {
          ...(startDate ? { gte: startDate } : {}),
          ...(endDate ? { lte: endDate } : {}),
        }
      } : {}),
    };

    const appWhere: any = {
      ...(jobId ? { jobId } : { job: { ownerId: userId } }),
      ...(startDate || endDate ? {
        createdAt: {
          ...(startDate ? { gte: startDate } : {}),
          ...(endDate ? { lte: endDate } : {}),
        }
      } : {}),
    };

    const [candTotal, candInterview, candHired, appTotal, appInterview, appHired, jobCount] =
      await Promise.all([
        prisma.candidate.count({ where: candWhere }),
        prisma.candidate.count({ where: { ...candWhere, status: 'INTERVIEW' } }),
        prisma.candidate.count({ where: { ...candWhere, status: 'HIRED' } }),
        prisma.application.count({ where: appWhere }),
        prisma.application.count({ where: { ...appWhere, stage: 'INTERVIEW' } }),
        prisma.application.count({ where: { ...appWhere, stage: 'HIRED' } }),
        prisma.job.count({
          where: {
            ownerId: userId,
            ...(jobId ? { id: jobId } : {}),
          },
        }),
      ]);

    return res.json({
      stats: {
        activeCandidates: candTotal + appTotal,
        interviews: candInterview + appInterview,
        hired: candHired + appHired,
        jobs: jobCount,
      },
    });
  }),
);

/**
 * @openapi
 * /dashboard/funnel:
 *   get:
 *     summary: Get hiring funnel statistics (candidate status groupings)
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: OK
 */
dashboardRouter.get(
  '/dashboard/funnel',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const userId = req.auth!.userId;
    const rawJobId = typeof req.query.jobId === 'string' ? req.query.jobId.trim() : undefined;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    const jobId = (rawJobId && uuidRegex.test(rawJobId)) ? rawJobId : undefined;
    const startDate = typeof req.query.startDate === 'string' ? new Date(req.query.startDate) : undefined;
    const endDate = typeof req.query.endDate === 'string' ? new Date(req.query.endDate) : undefined;
    if (startDate) startDate.setHours(0, 0, 0, 0);
    if (endDate) endDate.setHours(23, 59, 59, 999);

    const candWhere: any = {
      ownerId: userId,
      ...(jobId ? { jobId } : {}),
      ...(startDate || endDate ? {
        createdAt: {
          ...(startDate ? { gte: startDate } : {}),
          ...(endDate ? { lte: endDate } : {}),
        }
      } : {}),
    };

    const appWhere: any = {
      ...(jobId ? { jobId } : { job: { ownerId: userId } }),
      ...(startDate || endDate ? {
        createdAt: {
          ...(startDate ? { gte: startDate } : {}),
          ...(endDate ? { lte: endDate } : {}),
        }
      } : {}),
    };

    const [candGroups, appGroups] = await Promise.all([
      prisma.candidate.groupBy({
        by: ['status'],
        where: candWhere,
        _count: { status: true },
      }),
      prisma.application.groupBy({
        by: ['stage'],
        where: appWhere,
        _count: { stage: true },
      }),
    ]);

    const counts: Record<string, number> = {
      APPLIED: 0,
      PARSED: 0,
      SCREENED: 0,
      INTERVIEW: 0,
      OFFER: 0,
      HIRED: 0,
      REJECTED: 0,
    };

    for (const g of candGroups) {
      const statusUpper = g.status.toUpperCase();
      counts[statusUpper] = (counts[statusUpper] || 0) + g._count.status;
    }

    for (const g of appGroups) {
      const stageUpper = g.stage.toUpperCase();
      counts[stageUpper] = (counts[stageUpper] || 0) + g._count.stage;
    }

    return res.json({ funnel: counts });
  })
);

/**
 * @openapi
 * /dashboard/activity-timeline:
 *   get:
 *     summary: Get daily activity timeline (combined candidates and applications)
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: OK
 */
dashboardRouter.get(
  '/dashboard/activity-timeline',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const userId = req.auth!.userId;
    const rawJobId = typeof req.query.jobId === 'string' ? req.query.jobId.trim() : undefined;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    const jobId = (rawJobId && uuidRegex.test(rawJobId)) ? rawJobId : undefined;
    const startDate = typeof req.query.startDate === 'string' ? new Date(req.query.startDate) : undefined;
    const endDate = typeof req.query.endDate === 'string' ? new Date(req.query.endDate) : undefined;
    if (startDate) startDate.setHours(0, 0, 0, 0);
    if (endDate) endDate.setHours(23, 59, 59, 999);

    const fourteenDaysAgo = new Date();
    fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 13);
    fourteenDaysAgo.setHours(0, 0, 0, 0);

    const startRange = startDate ? startDate : fourteenDaysAgo;
    const endRange = endDate ? endDate : new Date();

    const [candidates, applications] = await Promise.all([
      prisma.candidate.findMany({
        where: {
          ownerId: userId,
          ...(jobId ? { jobId } : {}),
          createdAt: { gte: startRange, lte: endRange },
        },
        select: { createdAt: true },
      }),
      prisma.application.findMany({
        where: {
          ...(jobId ? { jobId } : { job: { ownerId: userId } }),
          createdAt: { gte: startRange, lte: endRange },
        },
        select: { createdAt: true },
      }),
    ]);

    const combined = [...candidates, ...applications];

    const daysDiff = Math.ceil((endRange.getTime() - startRange.getTime()) / (1000 * 60 * 60 * 24));
    const numDays = Math.min(Math.max(daysDiff, 1), 90);

    const timeline: { date: string; count: number }[] = [];
    for (let i = numDays - 1; i >= 0; i--) {
      const d = new Date(endRange);
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      timeline.push({ date: dateStr, count: 0 });
    }

    for (const entry of combined) {
      const dateStr = entry.createdAt.toISOString().split('T')[0];
      const tEntry = timeline.find((t) => t.date === dateStr);
      if (tEntry) {
        tEntry.count += 1;
      }
    }

    return res.json({ timeline });
  })
);

