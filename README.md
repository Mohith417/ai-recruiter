# ai-recruiter  
![GitHub stars](https://img.shields.io/github/stars/Mohith417/ai-recruiter?style=social)  
![GitHub license](https://img.shields.io/github/license/Mohith417/ai-recruiter)  
![Docker Pulls](https://img.shields.io/docker/pulls/Mohith417/ai-recruiter)  
![Node.js CI](https://github.com/Mohith417/ai-recruiter/actions/workflows/node.yml/badge.svg)

> **Full‑stack AI Recruitment System**  
> Built with Flutter (Dart), Node.js, PostgreSQL, Docker & Docker Compose.

---

## 📌 Problem Statement

Modern hiring teams struggle to manage candidate pipelines, automate resume processing, and analyze hiring metrics at scale. Existing solutions either lack real‑time integration or require costly subscriptions.  
**ai‑recruiter** bridges that gap by combining a cross‑platform mobile/web front‑end with a powerful, AI‑driven back‑end—all containerized for easy deployment.

---

## 🚀 Features

### Candidate Experience
| Feature | Description |
|---------|-------------|
| Live Dashboard | Real‑time status updates and personalized metrics |
| Smart Job Feed | AI‑ranked job listings with one‑click application |
| Instant Notifications | Push/SMS alerts for application updates |
| Profile Management | Auto‑populate CV data, track progress |

### Recruiter Experience
| Feature | Description |
|---------|-------------|
| Unified Kanban Board | Drag‑and‑drop pipeline management |
| AI Resume Parsing | PDF → structured data extraction |
| Culture‑Fit Scoring | NLP‑based alignment with company values |
| Analytics Dashboard | Visual hiring funnels, KPIs, team performance |
| Workflow Automation | Background queue for screening & background checks |

---

## 🛠️ Tech Stack

- **Frontend**: Flutter (Riverpod, GoRouter)
- **Backend**: Node.js / Express (TypeScript)
- **Database**: PostgreSQL (Prisma ORM)
- **Queue**: Redis + BullMQ
- **AI Services**: FastAPI (Python) – resume parsing, culture‑fit
- **Real‑time**: Socket.io
- **API Docs**: Swagger / OpenAPI
- **Containerization**: Docker, Docker Compose
- **CI/CD**: GitHub Actions (Node.js lint, unit tests)

---

## 📋 Prerequisites

| Item | Minimum Version |
|------|-----------------|
| Docker & Docker Compose | 20.10+ |
| Flutter SDK | 3.22+ (stable) |
| Node.js | 20+ |
| Yarn | 1.22+ (or npm) |
| PostgreSQL | 15+ (if you run locally without Docker) |
| Redis | 7+ (if you run locally without Docker) |

---

## ⚙️ Installation

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/Mohith417/ai-recruiter.git
cd ai-recruiter
```

### 2️⃣ Set Up Environment Variables

```bash
# api/.env
DATABASE_URL=postgresql://user:pass@localhost:5432/ai_recruiter
REDIS_URL=redis://localhost:6379
JWT_SECRET=super_secret_key
```

### 3️⃣ Build & Start Services

```bash
docker compose up -d --build
```

### 4️⃣ Run Database Migrations

```bash
docker compose exec api npx prisma migrate deploy
```

### 5️⃣ Run Front‑end

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

---

## 📚 Usage Examples

### Apply to a Job

```bash
curl -X POST http://localhost:4000/api/jobs/123/apply \
  -H "Content-Type: application/json" \
  -d '{"candidateId":"c456","resumePdfUrl":"https://..." }'
```

### Retrieve Pipeline

```bash
curl http://localhost:4000/api/pipeline?stage=interview \
  -H "Authorization: Bearer <JWT>"
```

---

## 🤝 Contributing

1. Fork the repo and create a feature branch: `git checkout -b feat/your-feature`
2. Write tests for your changes
3. Run tests: `yarn test` (backend) & `flutter test` (frontend)
4. Open a pull request

---

## 📄 License

This project is licensed under the **MIT License**

---

## 📞 Contact

- **GitHub**: [@Mohith417](https://github.com/Mohith417)
