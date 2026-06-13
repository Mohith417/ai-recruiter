import { io } from '../index.js';
import { prisma } from './prisma.js';

/**
 * Emit a Socket.IO event to a specific user room.
 */
export function emitToUser(userId: string, event: string, data: any) {
  try {
    io.to(userId).emit(event, data);

    // Also look up and emit to their email room
    prisma.user
      .findUnique({
        where: { id: userId },
        select: { email: true },
      })
      .then((user) => {
        if (user && user.email) {
          io.to(user.email).emit(event, data);
          // eslint-disable-next-line no-console
          console.log(`Socket.IO: Emitted copy of event "${event}" to email room "${user.email}"`);
        }
      })
      .catch((err) => {
        // eslint-disable-next-line no-console
        console.warn('Socket.IO warning: Failed to fetch user email for room emit:', err);
      });

    // eslint-disable-next-line no-console
    console.log(`Socket.IO: Emitted event "${event}" to user "${userId}"`);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(`Socket.IO error: Failed to emit event to user ${userId}:`, err);
  }
}
