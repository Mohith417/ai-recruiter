import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import swaggerUi from 'swagger-ui-express';
import path from 'path';

import { apiRateLimit } from './middleware/rate_limit.js';
import { swaggerSpec } from './swagger.js';
import { healthRouter } from './routes/health.js';
import { meRouter } from './routes/me.js';
import { jobsRouter } from './routes/jobs.js';
import { aiRouter } from './routes/ai.js';
import { candidatesRouter } from './routes/candidates.js';
import { applicationsRouter } from './routes/applications.js';
import { dashboardRouter } from './routes/dashboard.js';
import { interviewsRouter } from './routes/interviews.js';
import { auditLogsRouter } from './routes/audit_logs.js';
import { authRouter } from './routes/auth.js';


export function createApp() {
  const app = express();

  app.use(helmet());
  // Explicit CORS settings so Swagger "Try it out" works reliably across localhost/127.0.0.1.
  app.use(
    cors({
      origin: true,
      credentials: true,
      allowedHeaders: ['Content-Type', 'Authorization'],
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    }),
  );
  app.use(express.json({ limit: '50mb' }));
  app.use('/uploads', express.static(path.join(process.cwd(), '../.uploads')));
  app.use(morgan('dev'));
  app.use(apiRateLimit);

  app.use('/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

  app.use(authRouter);
  app.use(healthRouter);
  app.use(meRouter);
  app.use(jobsRouter);
  app.use(aiRouter);
  app.use(candidatesRouter);
  app.use(applicationsRouter);
  app.use(auditLogsRouter);
  app.use(dashboardRouter);
  app.use(interviewsRouter);


  // JSON error handler (important for async route errors in Express v4).
  // Without this, some thrown async errors can crash the process.
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    // Log once for debugging; keep response simple for the client.
    // eslint-disable-next-line no-console
    console.error(err);
    const status = Number(err?.statusCode ?? err?.status ?? 500);
    const message =
      typeof err?.message === 'string' && err.message.trim().length > 0 ? err.message.trim() : 'Internal server error';
    return res.status(status).json({ error: message });
  });

  app.use((req, res) => res.status(404).json({ error: 'Not found', path: req.path }));

  return app;
}
