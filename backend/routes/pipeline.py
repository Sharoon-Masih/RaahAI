# backend/routes/pipeline.py
# ============================================================
# /submit-case — End-to-end pipeline endpoint.
# Accepts raw text, runs all 5 agents, returns full CaseObject.
# This is the primary demo endpoint for the hackathon.
# ============================================================

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from backend.services import firebase_service
from backend.services.pipeline import run_pipeline
from shared.schemas import SubmissionSource

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/submit", tags=["Pipeline"])


class SubmitRawRequest(BaseModel):
    raw_input: str
    submission_source: str = "web_form"


@router.post(
    "/raw",
    summary="Submit raw text input and run full 5-agent pipeline",
    response_model=dict,
    status_code=status.HTTP_200_OK,
)
async def submit_raw(req: SubmitRawRequest) -> dict:
    """
    Full end-to-end pipeline endpoint.

    1. Intake Agent  → structures raw text into CaseObject
    2. Validation    → authenticates and flags case
    3. Severity & Impact → scores urgency and predicts time sensitivity
    4. Action        → generates execution plan and resource requests
    5. Dispatch      → assigns volunteer, generates ticket + SMS

    Returns the complete processed CaseObject.
    """
    try:
        case = await run_pipeline(
            raw_input=req.raw_input,
            submission_source=req.submission_source,
        )
    except Exception as exc:
        logger.error(f"[Pipeline] Unhandled error: {exc}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Pipeline execution failed: {str(exc)}",
        )

    # Store final state in Firebase
    try:
        await firebase_service.write_case(case.to_firestore_dict())
    except Exception as exc:
        logger.warning(f"[Pipeline] Firebase write failed after pipeline: {exc}")
        # Non-fatal — return result even if storage fails

    return {
        "success": True,
        "case_id": case.case_id,
        "ticket_id": case.ticket_id,
        "dispatch_status": case.dispatch_status.value if case.dispatch_status else None,
        "validation_status": case.validation_status.value if case.validation_status else None,
        "severity_score": case.severity_score,
        "severity_level": case.severity_level.value if case.severity_level else None,
        "time_sensitivity": case.time_sensitivity.value if case.time_sensitivity else None,
        "volunteer_assigned": case.volunteer_assigned,
        "sms_draft": case.sms_draft,
        "pipeline_stage": case.pipeline_stage,
        "trace_count": len(case.agent_trace),
        "case": case.to_firestore_dict(),
    }
