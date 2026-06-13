# AI Recruiter
### A high-performance, AI-driven recruitment platform built for modern hiring teams.

AI Recruiter is a comprehensive full-stack solution designed to streamline and automate the modern hiring lifecycle. By leveraging distributed systems and machine learning, it provides a seamless experience for both recruiters and candidates, featuring real-time synchronization, automated resume intelligence, and intuitive pipeline management.

---

## 🚀 Tech Stack

- **Frontend**: Flutter (Cross-platform), Riverpod (State Management), GoRouter
- **Backend**: Node.js, Express, TypeScript
- **Persistence**: PostgreSQL, Prisma ORM
- **Infrastructure**: Docker, Docker Compose
- **Concurrency & Queues**: Redis, BullMQ (Async processing)
- **Machine Learning**: FastAPI (Python), AI Resume Parsing, Culture-Fit Analysis
- **API Documentation**: Swagger / OpenAPI 3.0
- **Real-time**: Socket.io

---

## ✨ Key Features

### For Candidates
- **Live Dashboard**: Real-time tracking of application status and personal hiring metrics.
- **Smart Job Feed**: Efficient job discovery with one-click applications.
- **Instant Notifications**: Real-time alerts when applications are reviewed or updated.
- **Profile Management**: Professional profile hosting with automated status tracking.

### For Recruiters
- **Unified Pipeline**: Interactive Drag-and-Drop Kanban board for end-to-end candidate management.
- **AI Resume Intelligence**: Automated PDF parsing and data extraction into the candidate database.
- **Semantic Culture-Fit**: AI-powered assessment of candidate alignment with company core values.
- **Analytics Dashboard**: High-level overview of hiring funnels, activity timelines, and team performance.
- **Automated Workflows**: Real-time notifications for new applicants and background processing tasks.

---

## 🛠️ Local Development

### Prerequisites
- Docker & Docker Compose
- Flutter SDK (latest stable)
- Node.js 20+

### 1. Environment Configuration
Configure your local environment variables before starting the services.

**Backend:**
```bash
cp backend/.env.example backend/.env
# Update SUPABASE_URL and SUPABASE_JWT_AUD as needed
```

**Frontend:**
```bash
cp frontend/.env.example frontend/.env
# Ensure API_BASE_URL points to http://localhost:4000
```

### 2. Launch Infrastructure
Start the entire ecosystem (Database, Redis, API, Workers, and ML Service) using Docker:
```bash
docker compose up --build
```
The backend API will be available at `http://localhost:4000`.

### 3. Run the Flutter App
In a new terminal, launch the frontend:
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

---

## 📂 Project Structure

- `/frontend` - Flutter mobile and web application.
- `/backend` - Node.js API, BullMQ workers, and Prisma schema.
- `/ml_service` - FastAPI microservice for semantic analysis and embeddings.
- `/docker-compose.yml` - Infrastructure orchestration and service definitions.

---

## 📖 API Documentation

Once the backend is running, you can access the interactive API documentation (Swagger UI) at:
**`http://localhost:4000/docs`**

---

## 🖼️ Screenshots

*(Placeholder: Add screenshots of the Kanban board, Candidate Dashboard, and AI Analysis screens here)*

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
