# backend/config.py
# ============================================================
# Central configuration — loaded from .env
# ============================================================

import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env from project root or backend directory
_root = Path(__file__).parent.parent
load_dotenv(_root / ".env", override=False)
load_dotenv(Path(__file__).parent / ".env", override=False)


class Settings:
    # ── Firebase ─────────────────────────────────────────────
    FIREBASE_SERVICE_ACCOUNT_PATH: str = os.getenv(
        "FIREBASE_SERVICE_ACCOUNT_PATH", "firebase-adminsdk.json"
    )
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "")

    # Firestore collection names — single source of truth
    COLLECTION_CASES: str = "cases"
    COLLECTION_TRACES: str = "traces"
    COLLECTION_DISPATCH_LOGS: str = "dispatch_logs"
    COLLECTION_VOLUNTEERS: str = "volunteers"
    COLLECTION_NGOS: str = "ngos"

    # ── Gemini API ───────────────────────────────────────────
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-1.5-pro")

    # ── Google Sheets ────────────────────────────────────────
    GOOGLE_SHEETS_ID: str = os.getenv("GOOGLE_SHEETS_ID", "")

    # ── App ──────────────────────────────────────────────────
    APP_ENV: str = os.getenv("APP_ENV", "development")
    DEBUG: bool = APP_ENV == "development"
    API_PREFIX: str = "/api/v1"

    @property
    def is_production(self) -> bool:
        return self.APP_ENV == "production"


settings = Settings()
