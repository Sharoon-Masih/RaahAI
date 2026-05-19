# backend/main.py
# ============================================================
# RaahAI FastAPI MCP Server — Application Entry Point
#
# Architecture:
#   Antigravity Agents → POST /api/v1/ingest-case
#                      → POST /api/v1/firebase/update-case-status
#                      → POST /api/v1/firebase/log-trace
#                      → POST /api/v1/firebase/log-dispatch
#   Flutter Dashboard  → GET  /api/v1/firebase/cases
#                      → GET  /api/v1/firebase/stats
#   Dispatch Agent     → GET  /api/v1/firebase/volunteers
# ============================================================

import logging
import sys
from contextlib import asynccontextmanager

# pyrefly: ignore [missing-import]
import structlog
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from backend.config import settings
from backend.routes import firebase as firebase_router
from backend.routes import ingestion as ingestion_router
from backend.routes import pipeline as pipeline_router
from backend.routes import ngos as ngos_router
from backend.services import firebase_service
from backend.services import gemini_service
from backend.services import sheets_service
from backend.services.mcp_router import mcp_router

# ── Structured logging setup ────────────────────────────────

structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(logging.DEBUG),
    logger_factory=structlog.PrintLoggerFactory(file=sys.stdout),
)

logger = structlog.get_logger(__name__)


# ── Lifespan (startup / shutdown) ───────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Startup: Initialize Firebase and register MCP tools.
    Shutdown: Clean up resources.
    """
    logger.info("RaahAI MCP Server starting...", env=settings.APP_ENV)

    # Initialize Firebase — mandatory
    try:
        firebase_service.initialize_firebase()
        logger.info("Firebase Firestore initialized successfully.")
    except Exception as exc:
        logger.error("CRITICAL: Firebase initialization failed.", error=str(exc))
        # Allow startup to continue in dev mode without Firebase
        # (so engineers can test endpoints without credentials)
        if settings.is_production:
            raise

    # Initialize Gemini
    try:
        gemini_service.initialize_gemini()
        logger.info("Gemini API initialized successfully.")
    except Exception as exc:
        logger.warning("Gemini initialization warning.", error=str(exc))

    # Register MCP tools in router
    mcp_router.register("firebase", firebase_service)
    mcp_router.register("sheets", sheets_service)
    logger.info(
        "MCP tools registered.",
        tools=mcp_router.available_tools(),
    )

    yield  # Application running

    logger.info("RaahAI MCP Server shutting down.")


# ── FastAPI Application ──────────────────────────────────────

app = FastAPI(
    title="RaahAI MCP Tool Server",
    description=(
        "FastAPI backend acting as the MCP Tool Gateway for the RaahAI "
        "autonomous humanitarian NGO case intelligence pipeline.\n\n"
        "**Architecture:** Antigravity Agents → FastAPI → Firebase Firestore\n\n"
        "**Collections:** cases/ | traces/ | dispatch_logs/ | volunteers/"
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)


# ── CORS ─────────────────────────────────────────────────────
# Allow Flutter app and Antigravity to reach this server

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if not settings.is_production else [
        "https://raah-ai.web.app",
        "https://raah-ai.firebaseapp.com",
        "http://localhost:3000",
        "http://localhost:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Global exception handler ─────────────────────────────────

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(
        "Unhandled exception",
        path=request.url.path,
        method=request.method,
        error=str(exc),
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": "Internal server error",
            "detail": str(exc) if settings.DEBUG else "Contact system administrator.",
        },
    )


# ── Routers ──────────────────────────────────────────────────

app.include_router(ingestion_router.router, prefix=settings.API_PREFIX)
app.include_router(firebase_router.router, prefix=settings.API_PREFIX)
app.include_router(pipeline_router.router, prefix=settings.API_PREFIX)
app.include_router(ngos_router.router, prefix=settings.API_PREFIX)


# ── Health & Root ────────────────────────────────────────────

@app.get("/", tags=["Health"])
async def root():
    return {
        "system": "RaahAI MCP Tool Server",
        "version": "1.0.0",
        "status": "operational",
        "pipeline": "Intake → Validation → Severity&Impact → Action → Dispatch",
        "database": "Firebase Firestore",
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """
    Liveness probe — used by Cloud Run / Render.
    Verifies Firebase connection is alive.
    """
    try:
        db = firebase_service.get_db()
        # Light probe — try to access collections list
        db.collections()
        firebase_ok = True
        firebase_msg = "connected"
    except Exception as exc:
        firebase_ok = False
        firebase_msg = str(exc)

    return {
        "status": "healthy" if firebase_ok else "degraded",
        "firebase": firebase_msg,
        "env": settings.APP_ENV,
        "mcp_tools": mcp_router.available_tools(),
    }
