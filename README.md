# ai-recruiter  

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
- [Prerequisites](#prerequisites)  
- [Installation & Setup](#installation--setup)  
- [Running the Application](#running-the-application)  
- [Usage Examples](#usage-examples)  
- [API Documentation](#api-documentation)  
- [Testing](#testing)  
- [Contributing](#contributing)  
- [License](#license)  
- [Roadmap & Future Work](#roadmap--future-work)  

---  

## Problem Statement
Hiring teams today face several pain points:

| Pain point | Why it matters |
|------------|----------------|
| **Fragmented candidate pipelines** | Recruiters switch between ATS, email, and spreadsheets, leading to data loss and duplicated effort. |
| **Manual resume processing** | Parsing PDFs by hand is time‑consuming and error‑prone. |
| **Lack of real‑time insights** | Decision makers cannot see pipeline health or hiring metrics instantly. |
| **High subscription costs** | Many SaaS ATS solutions charge per user or per seat. |

**ai-recruiter** solves these issues by delivering an end‑to‑end, AI‑augmented recruitment platform that is **open‑source**, **containerized**, and **cost‑effective**.

---  

## Key Features  

### Candidate Experience
| Feature | Description |
|---------|-------------|
| **Live Dashboard** | Real‑time status updates, personalized metrics, and application timeline. |
| **Smart Job Feed** | AI‑ranked listings based on candidate profile & preferences. |
| **Instant Notifications** | Push and SMS alerts for interview invites, status changes, etc. |
| **Profile Management** | One‑click CV upload → auto‑populate fields using AI resume parsing. |

### Recruiter Experience
| Feature | Description |
|---------|-------------|
| **Unified Kanban Board** | Drag‑and‑drop pipeline stages (Applied, Screening, Interview, Offer, etc.). |
| **AI Resume Parsing** | PDF → structured JSON (experience, skills, education) via a FastAPI micro‑service. |
| **Culture‑Fit Scoring** | NLP‑based match between candidate answers and company values. |
| **Analytics Dashboard** | Funnel visualisation, time‑to‑hire, source effectiveness, team performance. |
| **Workflow Automation** | Background queues (BullMQ + Redis) for screening, background checks, email sequencing. |
| **Real‑time Collaboration** | Socket.io powered updates for multiple recruiters working on the same board. |

---  

## Tech Stack
| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter (Dart) – Riverpod, GoRouter, Flutter Web & Mobile |
| **Backend** | Node.js + Express (TypeScript) |
| **Database** | PostgreSQL + Prisma ORM |
| **Message Queue** | Redis + BullMQ |
| **AI Services** | Python FastAPI (OpenAI / HuggingFace models for resume parsing, culture‑fit) |
| **Real‑time** | Socket.io |
| **API Docs** | Swagger / OpenAPI (served at `/api/docs`) |
| **Containerisation** | Docker + Docker‑Compose |
| **CI/CD** | GitHub Actions (Node tests, linting, Docker image build) |

---  

## Prerequisites
| Tool | Minimum Version |
|------|-----------------|
| **Git** | 2.30+ |
| **Docker** | 24.0+ (Docker Engine) |
| **Docker‑Compose** | v2.20+ |
| **Flutter SDK** | 3.19+ |
| **Node.js** | 20.x (runtime; Docker image uses 20) |
| **npm / Yarn** | npm 10.x (or Yarn 1.22) |
| **Python** | 3.11 (only required for AI micro‑service; bundled in Docker) |
| **psql** (optional) | 15+ for local DB access |

---  

## Installation & Setup  

### 1. Clone the repository
```bash
git clone https://github.com/Mohith417/ai-recruiter.git
cd ai-recruiter
```

### 2. Create environment files  

Copy the example files and edit values to match your environment.

```bash
# Backend (Node)
cp backend/.env.example backend/.env

# AI service (FastAPI)
cp ai-service/.env.example ai-service/.env

# Database (PostgreSQL)
cp postgres/.env.example postgres/.env
```

> **Important:**  
> - Set `POSTGRES_PASSWORD`, `POSTGRES_USER`, and `POSTGRES_DB` in `postgres/.env`.  
> - In `backend/.env` configure `DATABASE_URL` (e.g. `postgresql://postgres:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}`) and `REDIS_URL`.  
> - In `ai-service/.env` provide your OpenAI/HuggingFace API key (`OPENAI_API_KEY` or `HF_API_KEY`).  

### 3. Build and start containers  

```bash
docker compose up --build -d
```

Docker Compose will spin up:

| Service | Purpose |
|---------|---------|
| `db` | PostgreSQL |
| `redis` | Message queue broker |
| `backend` | Node/Express API |
| `ai-service` | FastAPI resume‑parsing service |
| `frontend` | Flutter web compiled to static assets (served by Nginx) |
| `nginx` | Reverse proxy for `/api/*` and web UI |

### 4. Run database migrations  

```bash
docker compose exec backend npx prisma migrate deploy
```

### 5. Install Flutter dependencies (optional – for local development)

```bash
cd frontend
flutter pub get
```

---  

## Running the Application  

| Mode | Command | Description |
|------|---------|-------------|
| **Docker (production‑like)** | `docker compose up -d` | Full stack in containers (recommended). |
| **Backend only (dev)** | `cd backend && npm run dev` | Hot‑reload with `nodemon`. |
| **AI service only (dev)** | `cd ai-service && uvicorn main:app --reload` | FastAPI dev server on `http://localhost:8000`. |
| **Flutter (local)** | `cd frontend && flutter run -d chrome` | Launch the web UI in Chrome. |
| **Flutter (mobile)** | `flutter run` | Run on attached Android/iOS device or emulator. |

The application will be reachable at:  

- **Web UI** – `http://localhost` (Nginx)  
- **API** – `http://localhost/api/v1/` (Swagger UI at `/api/docs`)  
- **AI Service** – `http://localhost:8000/docs`  

---  

## Usage Examples  

### 1. Create a new job posting (cURL)

```bash
curl -X POST http://localhost/api/v1/jobs \
  -H "Content-Type: application/json" \
  -d '{
        "title": "Senior Flutter Engineer",
        "description": "Build beautiful cross‑platform apps.",
        "location": "Remote",
        "requirements": ["5+ years Flutter", "CI/CD experience"]
      }' | jq .
```

### 2. Upload a candidate resume (Node client)

```typescript
import axios from 'axios';
import FormData from 'form-data';
import fs from 'fs';

const form = new FormData();
form.append('file', fs.createReadStream('resume.pdf'));

axios.post('http://localhost/api/v1/candidates', form, {
  headers: form.getHeaders(),
})
.then(res => console.log('Candidate created:', res.data))
.catch(err => console.error(err.response?.data));
```

### 3. Get AI‑parsed resume data (FastAPI endpoint)

```bash
curl -X POST http://localhost:8000/parse \
  -F "file=@resume.pdf" \
  -H "accept: application/json"
```

_Response (truncated)_

```json
{
  "name": "Jane Doe",
  "email": "jane.doe@example.com",
  "skills": ["Flutter", "Dart", "Node.js", "Docker"],
  "experience": [
    {
      "company": "TechCo",
      "role": "Mobile Engineer",
      "duration": "2 years"
    }
  ]
}
```

### 4. Real‑time updates with Socket.io (Flutter)

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socket = IO.io('http://localhost', <String, dynamic>{
  'transports': ['websocket'],
  'autoConnect': false,
});

socket.onConnect((_) => print('connected'));
socket.on('pipeline:update', (data) => print('Pipeline changed: $data'));
socket.connect();
```

---  

## API Documentation  

The backend automatically generates Swagger/OpenAPI docs.

- **URL:** `http://localhost/api/docs`  
- **Version:** `v1`  
- **Authentication:** JWT (`Authorization: Bearer <token>`)

Endpoints include:

| Category | Path | Method | Description |
|----------|------|--------|-------------|
| Auth | `/auth/login` | POST | Generate JWT token |
| Jobs | `/jobs` | GET, POST | List/create jobs |
| Candidates | `/candidates` | GET, POST, PATCH | CRUD for candidates |
| Pipelines | `/pipelines/:id` | GET, PATCH | View / move candidates |
| Analytics | `/analytics/hiring-funnel` | GET | Funnel metrics |
| AI Service | `/parse` (FastAPI) | POST | Parse PDF resume → JSON |

---  

## Testing  

### Backend (Node)

```bash
cd backend
npm run test          # Jest unit & integration tests
npm run lint          # ESLint
```

### AI Service (Python)

```bash
cd ai-service
pytest                # Pytest suite
flake8 .               # Linting
```

### Flutter UI

```bash
cd frontend
flutter test          # Widget & unit tests
flutter analyze       # Dart analyzer
```

All CI pipelines are defined in `.github/workflows/` and run on every push.

---  

## Contributing  

We welcome contributions! Please follow these steps:

1. **Fork** the repository and **clone** your fork.  
2. **Create a feature branch** (`git checkout -b feature/awesome-idea`).  
3. **Write code** adhering to the existing style guides:  
   - Dart: `flutter format`, `flutter analyze`  
   - TypeScript: `eslint`, `prettier` (run `npm run lint -- --fix`)  
   - Python: `black`, `flake8`  
4. **Add tests** for new functionality.  
5. **Commit** with a clear message (`git commit -m "feat: add AI‑driven culture‑fit scoring"`).  
6. **Push** to your fork and open a **Pull Request** against `main`.  
7. Ensure **all CI checks** pass before merging.  

Please read our full [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines, coding standards, and the review process.

---  

## License  

This project is licensed under the **MIT License** – see the [LICENSE](LICENSE) file for details.

---  

## Roadmap & Future Work  

- **Multi‑tenant SaaS mode** – separate databases per organization.  
- **Interview scheduling** – calendar integration (Google/Outlook).  
- **Advanced AI** – sentiment analysis of video interviews.  
- **Mobile‑first offline support** – local storage sync when connectivity restores.  
- **Metrics export** – Prometheus + Grafana dashboards.  

Feel free to propose ideas via **GitHub Issues** or join the discussion in the repository’s **Discussions** tab.  

---  

*Happy recruiting! 🚀*
