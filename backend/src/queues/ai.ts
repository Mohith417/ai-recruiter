import { Queue } from 'bullmq';

import { redisConnection } from '../lib/redis.js';

export const aiQueue = new Queue('ai', {
  connection: redisConnection,
});

export type ResumeParseJob = {
  userId: string;
  resumeFileUrl: string;
  jobId?: string;
};
