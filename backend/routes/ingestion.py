# backend/routes/ingestion.py
# ============================================================
# /ingest-case — Primary intake endpoint.
# Receives a CaseObject from Intake Agent (already structured by Gemini).
# Validates schema, writes to Firebase, logs trace.
# ============================================================

from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status

from backend.services import firebase_service
from shared.schemas import CaseObject, DispatchStatus, TraceObject

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ingest-case", tags=["Ingestion"])


@router.post(
    "",
    summary="Ingest a structured CaseObject from Intake Agent",
    status_code=status.HTTP_201_CREATED,
    response_model=dict,
)
async def ingest_case(case: CaseObject) -> dict:
    """
    Receives a CaseObject produced by the Intake Agent.

    Pipeline contract:
    - case.pipeline_stage must be 'INTAKE_COMPLETE' or 'INTAKE_FAILED'
    - dispatch_status must be 'PENDING' or 'FAILED'
    - agent_trace must contain at least one entry from IntakeAgent

    Actions:
    1. Validate the CaseObject against schema (handled by Pydantic)
    2. Write to Firebase cases/ collection
    3. Write each trace entry to Firebase traces/ collection
    4. Return case_id confirmation

    NEVER modifies the CaseObject — read-only + store.
    """

    # ── Guard: Reject if pipeline_stage is not an intake stage ──
    valid_stages = {"INTAKE_COMPLETE", "INTAKE_FAILED"}
    if case.pipeline_stage not in valid_stages:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Invalid pipeline_stage '{case.pipeline_stage}' for ingestion. "
                f"Expected one of: {valid_stages}"
            ),
        )

    # ── Guard: At least one IntakeAgent trace entry required ──
    intake_traces = [t for t in case.agent_trace if t.agent == "IntakeAgent"]
    if not intake_traces:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="CaseObject must contain at least one TraceObject from 'IntakeAgent'.",
        )

    case_dict = case.to_firestore_dict()

    # ── Write case to Firestore ──────────────────────────────
    try:
        await firebase_service.write_case(case_dict)
    except Exception as exc:
        logger.error(f"Firebase write failed for case {case.case_id}: {exc}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Storage failure — case not ingested. Error: {str(exc)}",
        )

    # ── Write each trace entry independently ─────────────────
    for trace in case.agent_trace:
        try:
            await firebase_service.write_trace(
                case.case_id,
                trace.model_dump(mode="json"),
            )
        except Exception as exc:
            # Trace write failure is non-fatal — log but don't fail request
            logger.warning(
                f"Trace write failed for case {case.case_id}, "
                f"agent {trace.agent}: {exc}"
            )

    logger.info(
        f"[Ingestion] Case {case.case_id} ingested. "
        f"Stage: {case.pipeline_stage}. Status: {case.dispatch_status}."
    )

    return {
        "success": True,
        "case_id": case.case_id,
        "pipeline_stage": case.pipeline_stage,
        "dispatch_status": case.dispatch_status,
        "message": f"Case {case.case_id} stored in Firebase successfully.",
    }
