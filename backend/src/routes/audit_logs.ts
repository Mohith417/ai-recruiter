import { Router } from 'express';
import { prisma, Role } from '../lib/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/rbac.js';

export const auditLogsRouter = Router();

const recruiterRoles = [Role.RECRUITER, Role.HR_MANAGER, Role.ADMIN, Role.COMPANY];

// Wrapper to safely forward rejected promises to Express error handler
const asyncRoute =
  (fn: (req: any, res: any, next: any) => Promise<any>) =>
  (req: any, res: any, next: any) =>
    Promise.resolve(fn(req, res, next)).catch(next);

/**
 * @openapi
 * /audit-logs:
 *   get:
 *     summary: List audit logs for the current user (recruiter)
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: OK
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 auditLogs:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id: { type: string, format: uuid }
 *                       createdAt: { type: string, format: date-time }
 *                       action: { type: string }
 *                       entity: { type: string }
 *                       entityId: { type: string, nullable: true }
 *                       meta: { type: object, nullable: true }
 */
auditLogsRouter.get(
  '/audit-logs',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const logs = await prisma.auditLog.findMany({
      where: { actorId: req.auth!.userId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    return res.json({ auditLogs: logs });
  }),
);

/**
 * @openapi
 * /audit-logs:
 *   delete:
 *     summary: Delete all audit logs for the current user
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: OK
 */
auditLogsRouter.delete(
  '/audit-logs',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const userId = req.auth!.userId;

    await prisma.auditLog.deleteMany({
      where: { actorId: userId },
    });

    return res.json({ success: true });
  }),
);

/**
 * @openapi
 * /audit-logs/restore:
 *   post:
 *     summary: Restore deleted audit logs
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               logs:
 *                 type: array
 *                 items:
 *                   type: object
 *     responses:
 *       200:
 *         description: OK
 */
auditLogsRouter.post(
  '/audit-logs/restore',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const userId = req.auth!.userId;
    const { logs } = req.body;

    if (!Array.isArray(logs)) {
      return res.status(400).json({ error: 'logs must be an array' });
    }

    const dataToInsert = logs.map((log: any) => ({
      id: log.id,
      createdAt: new Date(log.createdAt),
      actorId: userId,
      action: log.action,
      entity: log.entity,
      entityId: log.entityId,
      meta: log.meta || {},
    }));

    await prisma.auditLog.createMany({
      data: dataToInsert,
      skipDuplicates: true,
    });

    return res.json({ success: true });
  }),
);

/**
 * @openapi
 * /audit-logs/{id}:
 *   delete:
 *     summary: Delete a specific audit log
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: OK
 */
auditLogsRouter.delete(
  '/audit-logs/:id',
  requireAuth,
  requireRole(recruiterRoles),
  asyncRoute(async (req, res) => {
    const { id } = req.params;
    const userId = req.auth!.userId;

    const log = await prisma.auditLog.findUnique({
      where: { id },
    });

    if (!log) {
      return res.status(404).json({ error: 'Audit log not found' });
    }

    if (log.actorId !== userId) {
      return res.status(403).json({ error: 'Forbidden: You do not own this audit log' });
    }

    await prisma.auditLog.delete({
      where: { id },
    });

    return res.json({ success: true });
  }),
);
