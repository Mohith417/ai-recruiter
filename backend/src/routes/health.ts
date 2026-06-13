import { Router } from 'express';

export const healthRouter = Router();

/**
 * @openapi
 * /health:
 *   get:
 *     summary: Health check
 *     responses:
 *       200:
 *         description: OK
 */
healthRouter.get('/health', (_req, res) => res.json({ ok: true }));
