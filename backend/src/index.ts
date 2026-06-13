import 'dotenv/config';
import http from 'http';
import { Server } from 'socket.io';

import { createApp } from './app.js';
import { prisma } from './lib/prisma.js';

const port = Number(process.env.PORT ?? 4000);

const app = createApp();
const server = http.createServer(app);

export const io = new Server(server, {
  cors: { origin: '*', credentials: true },
});

io.on('connection', (socket) => {
  socket.emit('hello', { ok: true, ts: Date.now() });

  socket.on('join', (data: { userId?: string; email?: string }) => {
    if (data) {
      if (data.userId) {
        socket.join(data.userId);
        // eslint-disable-next-line no-console
        console.log(`Socket ${socket.id} joined room for user ID ${data.userId}`);
      }
      if (data.email) {
        socket.join(data.email);
        // eslint-disable-next-line no-console
        console.log(`Socket ${socket.id} joined room for email ${data.email}`);
      }
    }
  });
});

const sentReminders = new Set<string>();

async function checkInterviewReminders() {
  try {
    const now = new Date();
    const thirtyMinutesFromNow = new Date(now.getTime() + 30 * 60 * 1000);

    const upcoming = await prisma.interview.findMany({
      where: {
        status: 'SCHEDULED',
        scheduledAt: {
          gte: now,
          lte: thirtyMinutesFromNow,
        },
      },
      include: {
        candidate: {
          select: { name: true },
        },
      },
    });

    for (const interview of upcoming) {
      if (!sentReminders.has(interview.id)) {
        sentReminders.add(interview.id);

        const timeDiff = interview.scheduledAt.getTime() - now.getTime();
        const minutesLeft = Math.max(1, Math.round(timeDiff / (60 * 1000)));

        const user = await prisma.user.findUnique({
          where: { id: interview.ownerId },
          select: { email: true },
        });

        const payload = {
          type: 'INTERVIEW_REMINDER',
          interviewId: interview.id,
          candidateName: interview.candidate?.name ?? 'Candidate',
          minutesLeft,
        };

        io.to(interview.ownerId).emit('notification', payload);
        if (user && user.email) {
          io.to(user.email).emit('notification', payload);
        }

        // eslint-disable-next-line no-console
        console.log(`Socket.IO: Emitted interview reminder notification for ${interview.id}`);
      }
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Error checking interview reminders:', err);
  }
}

// Start periodic checks
setInterval(checkInterviewReminders, 20000);

server.listen(port, async () => {
  try {
    await prisma.$executeRawUnsafe('CREATE EXTENSION IF NOT EXISTS vector;');
    // eslint-disable-next-line no-console
    console.log('PostgreSQL pgvector extension verified.');
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('Failed to initialize pgvector extension:', (err as Error).message);
  }
  if (!process.env.SUPABASE_URL) {
    // eslint-disable-next-line no-console
    console.warn('\x1b[33m%s\x1b[0m', 'WARNING: SUPABASE_URL is not configured inside the backend .env file. Auth token validation will fail.');
  }
  // eslint-disable-next-line no-console
  console.log(`API listening on http://localhost:${port}`);
  // eslint-disable-next-line no-console
  console.log(`Swagger on http://localhost:${port}/docs`);
});
