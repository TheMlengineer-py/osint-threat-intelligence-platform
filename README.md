# OSINT Threat Intelligence Platform

AI-driven Open Source Intelligence platform for automated threat monitoring,
risk assessment, and analyst decision support.

## Live Demo

| Service  | URL                                                               |
|----------|-------------------------------------------------------------------|
| Frontend | https://osint-threat-intelligence-platform.netlify.app            |
| API Docs | https://osint-threat-intelligence-platform-82p9.onrender.com/docs |

---

## Architecture

| Component    | Technology                       | Hosting          |
|--------------|----------------------------------|------------------|
| Frontend     | React 18 + TypeScript + Vite     | Netlify          |
| Backend      | FastAPI + Python 3.11            | Render (Docker)  |
| Database     | PostgreSQL                       | Render managed   |
| LLM          | Groq API (llama-3.1-8b-instant)  | Groq cloud       |
| NLP          | spaCy en_core_web_sm             | On-server        |
| Vector Store | ChromaDB                         | In-memory        |
| Scheduler    | APScheduler                      | On-server        |
| CI/CD        | GitHub Actions                   | GitHub           |

---

## Features

- Multi-source OSINT ingestion: CISA/NVD, RSS feeds (BleepingComputer, SecurityWeek), NewsAPI
- LangGraph multi-agent orchestration: collection, classification, risk scoring, reporting
- RAG-powered AI Copilot via Groq (llama-3.1-8b-instant) + ChromaDB
- Real-time threat dashboard with KPI tiles, global threat map, trend charts
- IOC extraction, entity recognition, MITRE ATT&CK mapping
- JWT authentication, role-based access control
- Airflow DAG for scheduled ingestion pipelines
- Dark/light theme, alert feed, analyst feedback

---

## Quick Start (Local)

```bash

git clone https://github.com/TheMlengineer-py/osint-threat-intelligence-platform
cd osint-threat-intelligence-platform

# Backend
cd backend

pip install -r requirements.txt
cp ../.env.example .env   # add your keys
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Frontend (new terminal)
cd frontend
npm install
npm run dev
```

Open `http://localhost:5174`

---

## Environment Variables

### Backend (.env)

| Variable        | Description                          | Required |
|-----------------|--------------------------------------|----------|
| DATABASE_URL    | PostgreSQL connection string         | Yes      |
| GROQ_API_KEY    | Groq API key for LLM                 | Yes      |
| GROQ_MODEL      | Model name (llama-3.1-8b-instant)    | No       |
| SECRET_KEY      | JWT signing secret                   | Yes      |
| LLM_PROVIDER    | groq or none                         | No       |

### Frontend (.env)

| Variable              | Description              |
|-----------------------|--------------------------|
| VITE_API_URL          | Backend API base URL     |
| VITE_ENVIRONMENT      | production or development|

---

## Deployment

### Backend → Render

1. Push to GitHub
2. New Web Service → connect repo → Root: `backend`
3. Runtime: Docker (uses `backend/Dockerfile`)
4. Set environment variables in Render dashboard:
   - `DATABASE_URL` = PostgreSQL internal URL from Render DB
   - `GROQ_API_KEY` = your Groq key
   - `GROQ_MODEL` = `llama-3.1-8b-instant`
   - `SECRET_KEY` = random secret
5. Create a Render PostgreSQL database (free tier)
6. Link internal DB URL to `DATABASE_URL`

### Frontend → Netlify

1. New site → connect repo → Base: `frontend`
2. Build: `npm run build` | Publish: `dist`
3. Set `VITE_API_URL` = your Render backend URL
4. Set `VITE_ENVIRONMENT` = `production`

---

## CI/CD

GitHub Actions runs on every push:
- `backend-ci.yml`: pytest unit + integration tests, ruff linting
- `frontend-ci.yml`: TypeScript check, Vitest unit tests
- `branch-name-check.yml`: enforces branch naming conventions

---

---

## API Reference

| Method | Endpoint                        | Description              |
|--------|---------------------------------|--------------------------|
| GET    | /api/v1/analytics/dashboard     | KPI tiles                |
| GET    | /api/v1/analytics/trends        | Threat trend data        |
| GET    | /api/v1/analytics/top-threats   | Top N threats by risk    |
| GET    | /api/v1/threats                 | List threats             |
| POST   | /api/v1/threats/ingest          | Trigger OSINT ingestion  |
| POST   | /api/v1/copilot/ask             | AI Copilot query         |
| GET    | /api/v1/copilot/status          | LLM status check         |
| GET    | /api/v1/reports                 | List reports             |
| GET    | /health                         | Health check             |
