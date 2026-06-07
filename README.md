# OSINT Threat Intelligence Platform

AI-driven Open Source Intelligence platform for automated threat monitoring,
risk assessment, and analyst decision support.

---

## Platform

| Component    | Technology                        | Hosting     |
|---|---|-------------|
| Frontend     | React 18 + TypeScript + Vite      | Netlify     |
| Backend      | FastAPI + Python 3.12             | Render      |
| Database     | SQLite (dev) / PostgreSQL (prod)  | Render disk |
| LLM          | Groq API (llama-3.1-8b-instant)   | Groq cloud  |
| NLP          | spaCy + custom classifiers        | On-server   |
| Vector Store | ChromaDB                          | In-memory   |
| Scheduler    | APScheduler + Airflow DAG         | On-server   |

## Quick Start (Local)

```bash
git clone https://github.com/your-org/osint-threat-intelligence-platform
cd osint-threat-intelligence-platform

# Backend
cd backend && pip install -r requirements.txt
cp .env.example .env    # add GROQ_API_KEY
python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Frontend (new terminal)
cd frontend && npm install && npm run dev
```

Open `http://localhost:5174`

## Deployment

### Backend → Render

1. Push to GitHub
2. New Web Service → connect repo
3. Root: `backend` | Build: `pip install -r requirements.txt`
4. Start: `uvicorn src.main:app --host 0.0.0.0 --port $PORT`
5. Set env vars:

GROQ_API_KEY=gsk_...
GROQ_MODEL=llama-3.1-8b-instant
DATABASE_URL=sqlite:///./osint.db
SECRET_KEY=your-secret-key
CORS_ORIGINS=https://your-site.netlify.app


### Frontend → Netlify

1. New site from Git → connect repo
2. Base: `frontend` | Build: `npm run build` | Publish: `dist`
3. Set env var: `VITE_API_BASE_URL=https://your-backend.onrender.com`

## Features

- **Real-time ingestion** — CISA KEV, RSS feeds, SecurityWeek, Krebs, BleepingComputer
- **AI Copilot** — RAG-powered analyst assistant via Groq (shared API key, no per-user setup)
- **Risk scoring** — `Risk = Likelihood × Impact × Confidence`
- **IOC extraction** — IPs, CVEs, domains, hashes, URLs via regex + NER
- **Threat classification** — 7 categories including APT, ransomware, phishing
- **Analytics** — trend charts, category distribution, source breakdown
- **Daily refresh** — Airflow DAG at 06:00 UTC + 30-min APScheduler fallback

## Groq API

The Groq key is configured once server-side. All platform users share it.
Free tier: **14,400 requests/day** — sufficient for a team of analysts.

## Tests

```bash
# Backend
cd backend && python -m pytest tests/ -v

# Frontend
cd frontend && npm run test

# E2E (requires both servers running)
cd frontend && npx playwright test
```

## Data Freshness

| Trigger              | Frequency             |
|---|-----------------------|
| Airflow DAG          | 06:00 UTC daily       |
| APScheduler          | Every 30 minutes      |
| Dashboard button     | On demand             |
| API endpoint         | POST /threats/process |
