"""
OSINT Threat Intelligence Platform — FastAPI Application
"""

import os
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="OSINT Threat Intelligence Platform",
    description="AI-driven OSINT threat monitoring and risk assessment",
    version="1.0.0",
)

# CORS — allow Netlify frontend and local dev
allowed_origins = [
    "https://osint-threat-intelligence-platform.netlify.app",
    "http://localhost:5173",
    "http://localhost:3000",
    "http://localhost:5174",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Import routes
try:
    from src.api.routes import analytics, copilot, reports, threats

    app.include_router(threats.router)
    app.include_router(copilot.router)
    app.include_router(reports.router)
    app.include_router(analytics.router)
    logger.info("All routers loaded successfully")
except Exception as e:
    logger.error(f"Failed to load routers: {e}")
    raise


@app.get("/health", tags=["system"])
def health_check():
    return {"status": "ok", "version": "1.0.0"}


@app.get("/", tags=["system"])
def root():
    return {
        "message": "OSINT Threat Intelligence Platform",
        "docs": "/docs",
        "health": "/health",
        "routes": {
            "threats": "/api/v1/threats",
            "copilot": "/api/v1/copilot",
            "reports": "/api/v1/reports",
            "analytics": "/api/v1/analytics",
        },
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("src.main:app", host="0.0.0.0", port=8000, reload=True)
