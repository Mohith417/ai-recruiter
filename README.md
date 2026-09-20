# ai‑recruiter  

[![GitHub stars](https://img.shields.io/github/stars/Mohith417/ai-recruiter?style=social)](https://github.com/Mohith417/ai-recruiter/stargazers)  
[![GitHub license](https://img.shields.io/github/license/Mohith417/ai-recruiter)](https://github.com/Mohith417/ai-recruiter/blob/main/LICENSE)  
[![Docker Pulls](https://img.shields.io/docker/pulls/Mohith417/ai-recruiter)](https://hub.docker.com/r/Mohith417/ai-recruiter)  
[![Node.js CI](https://github.com/Mohith417/ai-recruiter/actions/workflows/node.yml/badge.svg)](https://github.com/Mohith417/ai-recruiter/actions/workflows/node.yml)  

> **Full‑stack AI Recruitment System** – a cross‑platform (mobile/web) hiring platform powered by AI, built with Flutter, Node.js, PostgreSQL and Docker.

---

## Table of Contents
- [Problem Statement](#problem-statement)  
- [Key Features](#key-features)  
- [Tech Stack](#tech-stack)  
- [Architecture Overview](#architecture-overview)  
- [Prerequisites](#prerequisites)  
- [Quick Start (Docker Compose)](#quick-start-docker-compose)  
- [Local Development Setup](#local-development-setup)  
- [Configuration](#configuration)  
- [Running the Backend](#running-the-backend)  
- [Running the Front‑end (Flutter)](#running-the-frontend-flutter)  
- [API Documentation](#api-documentation)  
- [Real‑World Usage Examples](#real-world-usage-examples)  
- [Testing](#testing)  
- [Contributing](#contributing)  
- [License](#license)  

---

## Problem Statement  
Recruiters spend countless hours screening résumés, scheduling interviews, and matching candidates to job requirements. Traditional Applicant Tracking Systems (ATS) are often **manual**, **fragmented**, and **lack AI‑driven insights**.  

**ai‑recruiter** solves this by providing:

* A **single source of truth** for candidates, jobs, and interview data.  
* **AI‑assisted résumé parsing**, skill matching, and interview question generation.  
* Real‑time notifications via **WebSockets**.  
* Secure, role‑based access control (RBAC) and rate‑limited APIs.  
* Fully containerised deployment for easy scaling.

---

## Key Features
| Category | Feature |
|----------|---------|
| **Core API** | • Health check (`/health`) <br>• Authentication (`/auth`) with JWT & JWKS <br>• Role‑Based Access Control (RBAC) <br>• Rate limiting middleware |
| **Recruitment** | • CRUD for **Jobs**, **Candidates**, **Applications**, **Interviews** <br>• Dashboard statistics (`/dashboard`) |
| **AI Integration** | • `/ai` endpoints that enqueue AI jobs (e.g., résumé parsing, skill extraction) using BullMQ <br>• Worker (`src/worker.ts`) processes AI queues |
| **Observability** | • Swagger UI (`/api-docs`) <br>• Audit logs (`/audit_logs`) |
| **Realtime** | • Socket.IO server for live events (e.g., new application notifications) |
| **Data Layer** | • PostgreSQL via Prisma ORM <br>• Redis for caching, rate‑limit counters, and BullMQ job queue |
| **Security** | • Helmet, CORS, and CSRF‑hardening <br>• JWKS‑based RSA key pair generation |
| **DevOps** | • Dockerfile & Docker Compose (backend, PostgreSQL, Redis) <br>• GitHub Actions CI workflow |

---

## Tech Stack
| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter (Dart) – cross‑platform mobile & web UI |
| **Backend** | Node.js (TypeScript) + Express |
| **Database** | PostgreSQL (managed by Prisma) |
| **Cache / Queue** | Redis (ioredis) + BullMQ |
| **Realtime** | Socket.IO |
| **Auth** | JWT (RSA keys) + JWKS |
| **Containerisation** | Docker & Docker Compose |
| **CI/CD** | GitHub Actions |
| **Docs** | Swagger (OpenAPI 3) |

---

## Architecture Overview
```
┌─────────────────────┐      ┌─────────────────────┐
│   Flutter Front‑end │      │   Swagger UI (API)  │
│   (Dart)            │◄─────►  (http://localhost) │
└─────────▲───────────┘      └───────▲──────────────┘
          │                         │
          │   HTTP / WebSocket      │
          ▼                         ▼
   ┌─────────────────────┐   ┌─────────────────────┐
   │   Node.js API (Express)  │   Redis (Cache/Queue) │
   │   ├─ Routes            │   │   ├─ BullMQ          │
   │   ├─ Socket.IO        │   │   └─ Rate‑limit      │
   │   └─ Prisma (Postgres)│   └─────────────────────┘
   └─────────▲───────────┘
             │
             ▼
   ┌─────────────────────┐
   │   PostgreSQL (Data) │
   └─────────────────────┘
```

---

## Prerequisites
| Tool | Minimum Version |
|------|-----------------|
| Docker & Docker‑Compose | 20.10+ |
| Node.js | 20.x |
| npm (or yarn) | 9.x |
| PostgreSQL client (optional) | 14+ |
| Flutter SDK | 3.19+ |
| Git | any recent version |

---

## Quick Start (Docker Compose)

The repository contains a ready‑to‑use `docker-compose.yml` (not shown here) that brings up the backend, PostgreSQL, and Redis.

```bash
# Clone the repo
git clone https://github.com/Mohith417/ai-recruiter.git
cd ai-recruiter

# Copy example env file and edit if needed
cp backend/.env.example backend/.env

# Start all services
docker compose up --build -d

# Verify backend health
curl http://localhost:4000/health
# → {"status":"ok","timestamp":...}
```

The API docs are available at `http://localhost:4000/api-docs`.

---

## Local Development Setup

### 1️⃣ Backend

```bash
# Enter backend folder
cd backend

# Install dependencies
npm ci

# Create a local .env (based on the example)
cp .env.example .env
# Edit .env to match your local PostgreSQL / Redis credentials

# Run database migrations (Prisma)
npx prisma migrate dev --name init

# Start the API (watch mode)
npm run dev
# → Server listening on http://localhost:4000
```

### 2️⃣ Front‑end (Flutter)

```bash
# From the repository root
cd flutter-app   # <-- replace with your actual Flutter folder name

flutter pub get
flutter run   # Choose device/web as needed
```

> **Note:** The Flutter UI reads the backend URL from `lib/config.dart`. Adjust it to `http://10.0.2.2:4000` for Android emulator, `http://localhost:4000` for web, etc.

---

## Configuration

All backend settings are driven by environment variables (see `backend/.env.example`).

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP port for Express | `4000` |
| `DATABASE_URL` | Prisma‑compatible PostgreSQL DSN | `postgresql://postgres:postgres@localhost:5432/ai_recruiter` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `JWT_EXPIRES_IN` | JWT TTL (seconds) | `86400` |
| `RATE_LIMIT_WINDOW_MS` | Sliding window for rate limiting | `60000` |
| `RATE_LIMIT_MAX` | Max requests per window per IP | `100` |
| `ALLOWED_ORIGINS` | CORS whitelist (comma‑separated) | `*` |
| `AI_QUEUE_CONCURRENCY` | Number of concurrent AI workers | `3` |

> The JWKS key pair is generated at runtime (see `src/lib/jwks.ts`). For production you may want to persist the keys or use a dedicated JWKS endpoint.

---

## Running the Backend

```bash
# Build once
npm run build

# Start the compiled server
npm start

# Or run in watch mode (development)
npm run dev
```

### Starting the AI Worker

```bash
# In a separate terminal
npm run worker
# The worker consumes the `ai` BullMQ queue and executes AI jobs.
```

### Socket.IO Example

```ts
// client-side (Flutter/Dart or any JS client)
import { io } from "socket.io-client";

const socket = io("http://localhost:4000", {
  transports: ["websocket"],
  withCredentials: true,
});

socket.on("connect", () => {
  console.log("connected, id:", socket.id);
  socket.emit("join", { userId: "recruiter-123" });
});

socket.on("hello", (payload) => {
  console.log("Server greeting:", payload);
});

socket.on("application_created", (data) => {
  console.log("New application:", data);
});
```

---

## API Documentation

The OpenAPI spec is generated in `src/swagger.ts` and served via Swagger UI:

```
GET /api-docs          → Swagger UI
GET /api-docs.json     → Raw OpenAPI JSON
```

Key endpoints (excerpt):

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Liveness probe |
| `POST`| `/auth/login` | Returns JWT |
| `GET` | `/jobs` | List all job postings |
| `POST`| `/jobs` | Create a new job (RBAC: `admin`, `recruiter`) |
| `GET` | `/candidates/:id` | Get candidate profile |
| `POST`| `/applications` | Submit a candidate application |
| `GET` | `/interviews/:id` | Interview details |
| `POST`| `/ai/resume-parse` | Enqueue résumé parsing job |
| `GET` | `/dashboard` | Aggregated stats for the current user |

All routes are protected by `auth` middleware; see `src/middleware/auth.ts` for implementation details.

---

## Real‑World Usage Examples

### 1️⃣ Creating a Job (cURL)

```bash
curl -X POST http://localhost:4000/jobs \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "title": "Senior Flutter Engineer",
        "description": "Build beautiful cross‑platform apps",
        "location": "Remote",
        "salaryRange": "120000-150000",
        "requirements": ["Dart", "Flutter", "CI/CD"]
      }'
```

### 2️⃣ Submitting a Candidate Application (Node.js)

```ts
import axios from "axios";

const token = "YOUR_JWT";

await axios.post(
  "http://localhost:4000/applications",
  {
    candidateId: "cand-42",
    jobId: "job-7",
    coverLetter: "I am excited to join ..."
  },
  { headers: { Authorization: `Bearer ${token}` } }
);
```

### 3️⃣ Triggering AI Résumé Parsing

```ts
import axios from "axios";

await axios.post(
  "http://localhost:4000/ai/resume-parse",
  { candidateId: "cand-42", resumeUrl: "https://s3.amazonaws.com/.../resume.pdf" },
  { headers: { Authorization: `Bearer ${token}` } }
);
# The request returns a jobId; the worker will process it and store results in the DB.
```

### 4️⃣ Listening for Real‑Time Application Events (Flutter)

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socket = IO.io('http://localhost:4000', <String, dynamic>{
  'transports': ['websocket'],
  'autoConnect': false,
});

socket.connect();

socket.onConnect((_) {
  socket.emit('join', {'userId': user.id});
});

socket.on('application_created', (data) {
  // Show a push notification or update UI
  print('New application received: $data');
});
```

---

## Testing

The repository ships with Jest unit tests for the API layer.

```bash
# Run tests once
npm test

# Run tests in watch mode
npm run test:watch
```

Coverage reports are generated under `coverage/`.

---

## Contributing

Contributions are welcome! Please follow these steps:

1. **Fork** the repository and **clone** your fork.  
2. Create a feature branch: `git checkout -b feat/awesome-feature`.  
3. Install dependencies (`npm ci`) and ensure the code compiles (`npm run build`).  
4. Write tests for new functionality.  
5. Run the full test suite (`npm test`) and confirm coverage ≥ 80%.  
6. Lint & format code:
