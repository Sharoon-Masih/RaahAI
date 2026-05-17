# backend/services/firebase_service.py
# ============================================================
# Firebase Admin SDK — ONLY interface between FastAPI and Firestore.
# NO agent accesses Firestore directly. ALL writes go through here.
# ============================================================

from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import Any, Optional

import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1 import DocumentReference

from backend.config import settings

logger = logging.getLogger(__name__)

# ── Singleton guard ─────────────────────────────────────────

_app: Optional[firebase_admin.App] = None
_db: Optional[Any] = None  # firestore.Client


def _resolve_service_account() -> Optional[str]:
    """Find the Firebase service account JSON file."""
    candidates = [
        settings.FIREBASE_SERVICE_ACCOUNT_PATH,
        Path(__file__).parent.parent.parent / "firebase-adminsdk.json",
        Path(__file__).parent.parent / "firebase-adminsdk.json",
        Path(__file__).parent.parent.parent / ".secrets" / "firebase-adminsdk.json",
    ]
    for p in candidates:
        path = Path(p)
        if path.exists():
            return str(path)
    return None


def initialize_firebase() -> None:
    """
    Initialize Firebase Admin SDK once (idempotent).
    Called at FastAPI startup.
    """
    global _app, _db

    if _app is not None:
        return  # Already initialized

    sa_path = _resolve_service_account()

    try:
        if sa_path:
            cred = credentials.Certificate(sa_path)
            _app = firebase_admin.initialize_app(cred)
            logger.info(f"Firebase initialized with service account: {sa_path}")
        elif settings.FIREBASE_PROJECT_ID:
            # Use Application Default Credentials (GCP Cloud Run / local gcloud auth)
            cred = credentials.ApplicationDefault()
            _app = firebase_admin.initialize_app(
                cred, {"projectId": settings.FIREBASE_PROJECT_ID}
            )
            logger.info(
                f"Firebase initialized with ADC, project: {settings.FIREBASE_PROJECT_ID}"
            )
        else:
            raise RuntimeError(
                "Firebase not configured. Set FIREBASE_SERVICE_ACCOUNT_PATH or "
                "FIREBASE_PROJECT_ID in your .env file."
            )

        _db = firestore.client()
        logger.info("Firestore client ready.")

    except Exception as exc:
        logger.error(f"Firebase initialization failed: {exc}")
        raise


def get_db() -> Any:
    """Return initialized Firestore client. Raises if not initialized."""
    if _db is None:
        raise RuntimeError(
            "Firestore client is not initialized. Call initialize_firebase() first."
        )
    return _db


# ── Collection helpers ──────────────────────────────────────

def _col(name: str):
    return get_db().collection(name)


# ── cases/ ──────────────────────────────────────────────────

async def write_case(case_dict: dict) -> str:
    """
    Write a CaseObject dict to cases/{case_id}.
    Returns the case_id on success.
    Raises on Firestore error.
    """
    case_id: str = case_dict["case_id"]
    _col(settings.COLLECTION_CASES).document(case_id).set(case_dict)
    logger.info(f"[Firebase] cases/{case_id} written.")
    return case_id


async def get_case(case_id: str) -> Optional[dict]:
    """Retrieve a case document. Returns None if not found."""
    doc = _col(settings.COLLECTION_CASES).document(case_id).get()
    return doc.to_dict() if doc.exists else None


async def update_case_fields(case_id: str, fields: dict) -> None:
    """Partial update of a case document."""
    _col(settings.COLLECTION_CASES).document(case_id).update(fields)
    logger.info(f"[Firebase] cases/{case_id} updated: {list(fields.keys())}")


async def list_cases(limit: int = 100, status_filter: Optional[str] = None) -> list[dict]:
    """List cases with optional dispatch_status filter."""
    col = _col(settings.COLLECTION_CASES)
    query = col.order_by("pipeline_stage")
    if status_filter:
        query = col.where("dispatch_status", "==", status_filter)
    docs = query.limit(limit).stream()
    return [d.to_dict() for d in docs]


# ── traces/ ─────────────────────────────────────────────────

async def write_trace(case_id: str, trace_dict: dict) -> None:
    """
    Write an individual TraceObject to traces/{case_id}/entries/{agent}.
    The traces collection mirrors the agent_trace array for independent querying.
    """
    agent = trace_dict.get("agent", "unknown")
    doc_id = f"{case_id}__{agent}"
    _col(settings.COLLECTION_TRACES).document(doc_id).set(
        {"case_id": case_id, **trace_dict}
    )
    logger.info(f"[Firebase] traces/{doc_id} written.")


# ── dispatch_logs/ ──────────────────────────────────────────

async def write_dispatch_log(ticket_id: str, log_dict: dict) -> None:
    """Write a dispatch log to dispatch_logs/{ticket_id}."""
    _col(settings.COLLECTION_DISPATCH_LOGS).document(ticket_id).set(log_dict)
    logger.info(f"[Firebase] dispatch_logs/{ticket_id} written.")


async def get_dispatch_log(ticket_id: str) -> Optional[dict]:
    """Retrieve a dispatch log by ticket ID."""
    doc = _col(settings.COLLECTION_DISPATCH_LOGS).document(ticket_id).get()
    return doc.to_dict() if doc.exists else None


# ── volunteers/ ─────────────────────────────────────────────

async def get_available_volunteers() -> list[dict]:
    """Query all volunteers where is_available == True."""
    docs = (
        _col(settings.COLLECTION_VOLUNTEERS)
        .where("is_available", "==", True)
        .stream()
    )
    return [d.to_dict() for d in docs]


# ── stats ────────────────────────────────────────────────────

async def get_case_stats() -> dict:
    """Aggregate counts by dispatch_status for the dashboard."""
    from google.cloud.firestore_v1 import FieldFilter

    col = _col(settings.COLLECTION_CASES)
    all_docs = list(col.stream())
    total = len(all_docs)

    counts = {"PENDING": 0, "PROCESSING": 0, "DISPATCHED": 0, "FAILED": 0}
    critical = 0

    for doc in all_docs:
        data = doc.to_dict()
        status = data.get("dispatch_status", "PENDING")
        if status in counts:
            counts[status] += 1
        if data.get("severity_level") == "CRITICAL":
            critical += 1

    return {
        "total": total,
        "pending": counts["PENDING"],
        "processing": counts["PROCESSING"],
        "dispatched": counts["DISPATCHED"],
        "failed": counts["FAILED"],
        "critical": critical,
    }
