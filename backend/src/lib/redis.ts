import Redis from 'ioredis';

const redisUrl = process.env.REDIS_URL ?? 'redis://localhost:6379';

// Use this for app-level Redis commands.
export const redis = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
});

// Use this for BullMQ (avoids TS type conflicts caused by duplicate ioredis copies).
export const redisConnection = (() => {
  const u = new URL(redisUrl);
  const db = u.pathname && u.pathname !== '/' ? Number(u.pathname.replace('/', '')) : undefined;
  return {
    host: u.hostname,
    port: Number(u.port || 6379),
    ...(u.username ? { username: u.username } : {}),
    ...(u.password ? { password: u.password } : {}),
    ...(Number.isFinite(db) ? { db } : {}),
  };
})();
