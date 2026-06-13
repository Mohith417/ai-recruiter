import 'dotenv/config';
import { Worker } from 'bullmq';
import { createRequire } from 'module';

import { redisConnection } from './lib/redis.js';
import { prisma } from './lib/prisma.js';
import { emitToUser } from './lib/socket.js';

const require = createRequire(import.meta.url);
const { PDFParse } = require('pdf-parse');

async function downloadFile(url: string): Promise<Buffer> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download file from URL ${url}: ${response.statusText}`);
  }
  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

async function extractTextFromPdf(buffer: Buffer): Promise<string> {
  try {
    const parser = new PDFParse({ data: new Uint8Array(buffer) });
    const result = await parser.getText();
    return result.text;
  } catch (error) {
    throw new Error(`Failed to extract text from PDF: ${(error as Error).message}`);
  }
}

function parseResumeMetadata(text: string): { name?: string; email?: string } {
  // Simple regex to extract email
  const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/;
  const emailMatch = text.match(emailRegex);
  const email = emailMatch ? emailMatch[0] : 'contact@candidate.io';

  // Extract first non-empty line as name
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  const name = lines.length > 0 ? lines[0] : 'New Candidate';

  return { name, email };
}

async function parseResumeWithOpenAI(text: string): Promise<{ name?: string; email?: string }> {
  const apiKey = process.env.OPENAI_API_KEY;
  const modelName = process.env.AI_MODEL_NAME || 'gpt-4o-mini';
  if (!apiKey) {
    console.warn('OPENAI_API_KEY is not set. Using internal metadata parser.');
    return parseResumeMetadata(text);
  }

  const prompt = `You are a professional resume parser. Read the resume text below and extract:
1. Candidate Name (just the full name, e.g., "John Doe")
2. Candidate Email (e.g., "john.doe@example.com")

Provide the output strictly as a JSON object with the keys "name" and "email". Do not output markdown code blocks or any other explanation, just the raw JSON.

Resume text:
${text}`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: modelName,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.1,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`OpenAI API error: ${response.status} - ${errText}`);
  }

  const resJson = await response.json() as any;
  const content = resJson.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error('Invalid response structure from OpenAI API');
  }

  const parsed = JSON.parse(content);
  return {
    name: parsed.name || undefined,
    email: parsed.email || undefined,
  };
}

async function getEmbedding(text: string): Promise<number[] | null> {
  const mlServiceUrl = process.env.ML_SERVICE_URL || 'http://ml_service:8000';
  try {
    const response = await fetch(`${mlServiceUrl}/embeddings`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ texts: [text] }),
    });
    if (!response.ok) {
      console.warn(`ML service embeddings request failed: ${response.statusText}`);
      return null;
    }
    const resData = await response.json() as any;
    if (resData.vectors && resData.vectors.length > 0) {
      return resData.vectors[0];
    }
    return null;
  } catch (err) {
    console.warn(`Failed to connect to ML service at ${mlServiceUrl}: ${(err as Error).message}`);
    return null;
  }
}

// Run with: npm run worker
new Worker(
  'ai',
  async (job) => {
    if (job.name === 'resume.parse') {
      const { userId, resumeFileUrl, jobId } = job.data as {
        userId: string;
        resumeFileUrl: string;
        jobId?: string;
      };

      const cleanUrl = String(resumeFileUrl).replace(/[`'"]/g, '').trim();
      const linkedJobId = typeof jobId === 'string' && jobId.trim() ? jobId.trim() : null;

      if (linkedJobId) {
        const jobRow = await prisma.job.findFirst({
          where: { id: linkedJobId },
          select: { id: true },
        });
        if (!jobRow) throw new Error(`Job not found: ${linkedJobId}`);
      }

      // Download and parse resume
      let parsedName = 'Parsed resume';
      let parsedEmail: string | null = null;
      let resumeText: string | null = null;
      let embedding: number[] | null = null;

      try {
        console.log(`Downloading resume from: ${cleanUrl}`);
        const buffer = await downloadFile(cleanUrl);
        
        console.log('Extracting text from PDF...');
        const text = await extractTextFromPdf(buffer);
        resumeText = text;
        
        console.log('Parsing text with OpenAI...');
        const result = await parseResumeWithOpenAI(text);
        
        parsedName = result.name || parsedName;
        parsedEmail = result.email || null;

        console.log('Generating embedding for resume text...');
        embedding = await getEmbedding(text);
      } catch (err) {
        console.error('Error during AI resume parsing:', err);
      }

      const candidate = await prisma.candidate.create({
        data: {
          ownerId: userId,
          name: parsedName,
          email: parsedEmail,
          resumeFileUrl: cleanUrl,
          status: 'PARSED',
          jobId: linkedJobId,
          resumeText,
          embedding: embedding ? (embedding as any) : undefined,
        },
        select: { id: true },
      });

      await prisma.auditLog.create({
        data: {
          actorId: userId,
          action: 'AI_RESUME_PARSE_PROCESSED',
          entity: 'candidate',
          entityId: candidate.id,
          meta: {
            resumeFileUrl: cleanUrl,
            queueJobId: job.id,
            candidateId: candidate.id,
            jobId: linkedJobId,
          },
        },
      });

      emitToUser(userId, 'notification', {
        type: 'RESUME_PARSED',
        candidateId: candidate.id,
        name: parsedName,
      });

      return { ok: true, candidateId: candidate.id };
    }

    return { ok: true };
  },
  { connection: redisConnection },
);
