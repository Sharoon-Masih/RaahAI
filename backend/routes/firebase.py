# backend/routes/firebase.py
# ============================================================
# Firebase utility endpoints — used by pipeline agents and dashboard.
#
# Endpoints:
#   POST /update-case-status   — update dispatch_status + pipeline_stage
#   POST /log-trace            — append a TraceObject independently
#   POST /log-dispatch         — write to dispatch_logs/ collection
#   GET  /cases                — list cases (with optional status filter)
#   GET  /cases/{case_id}      — retrieve a single case
#   GET  /volunteers           — list available volunteers
#   GET  /stats                — aggregate counts for dashboard
# ============================================================

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status

from backend.services import firebase_service
from shared.schemas import DispatchStatus, TraceObject

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/firebase", tags=["Firebase"])


# ── POST /update-case-status ─────────────────────────────────

class CaseStatusUpdate:
    pass


from pydantic import BaseModel


class CaseStatusUpdateRequest(BaseModel):
    case_id: str
    dispatch_status: DispatchStatus
    pipeline_stage: str
    extra_fields: Optional[dict] = None


@router.post(
    "/update-case-status",
    summary="Update case dispatch_status and pipeline_stage",
    response_model=dict,
)
async def update_case_status(req: CaseStatusUpdateRequest) -> dict:
    """
    Allows agents to advance a case's status and pipeline stage.
    Only permitted fields: dispatch_status, pipeline_stage, plus optional extras.
    """
    fields = {
        "dispatch_status": req.dispatch_status.value,
        "pipeline_stage": req.pipeline_stage,
    }
    if req.extra_fields:
        # Safety: reject any attempt to modify protected schema fields via this endpoint
        _protected = {"case_id", "agent_trace", "description_original"}
        illegal = set(req.extra_fields.keys()) & _protected
        if illegal:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot modify protected fields via this endpoint: {illegal}",
            )
        fields.update(req.extra_fields)

    try:
        await firebase_service.update_case_fields(req.case_id, fields)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Firebase update failed: {exc}",
        )

    return {"success": True, "case_id": req.case_id, "updated_fields": list(fields.keys())}


# ── POST /log-trace ──────────────────────────────────────────

class LogTraceRequest(BaseModel):
    case_id: str
    trace: TraceObject


@router.post(
    "/log-trace",
    summary="Append a TraceObject to the traces collection",
    response_model=dict,
)
async def log_trace(req: LogTraceRequest) -> dict:
    """
    Independently persists an agent trace entry.
    Also appends it to the case document's agent_trace array.
    """
    trace_dict = req.trace.model_dump(mode="json")

    try:
        await firebase_service.write_trace(req.case_id, trace_dict)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Trace write failed: {exc}",
        )

    return {"success": True, "case_id": req.case_id, "agent": req.trace.agent}


# ── POST /log-dispatch ───────────────────────────────────────

class LogDispatchRequest(BaseModel):
    ticket_id: str
    log: dict  # Validated by Dispatch Agent before calling — flexible dict


@router.post(
    "/log-dispatch",
    summary="Write a dispatch log to dispatch_logs/ collection",
    response_model=dict,
)
async def log_dispatch(req: LogDispatchRequest) -> dict:
    """
    Called exclusively by Dispatch Agent.
    Stores final execution record in dispatch_logs/{ticket_id}.
    """
    try:
        await firebase_service.write_dispatch_log(req.ticket_id, req.log)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Dispatch log write failed: {exc}",
        )

    return {"success": True, "ticket_id": req.ticket_id}


# ── GET /cases ───────────────────────────────────────────────

@router.get(
    "/cases",
    summary="List cases from Firebase",
    response_model=list,
)
async def list_cases(
    status_filter: Optional[str] = Query(default=None, description="Filter by dispatch_status"),
    limit: int = Query(default=50, ge=1, le=500),
) -> list:
    try:
        return await firebase_service.list_cases(limit=limit, status_filter=status_filter)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Firestore read failed: {exc}",
        )


# ── GET /cases/{case_id} ─────────────────────────────────────

@router.get(
    "/cases/{case_id}",
    summary="Retrieve a single case by ID",
    response_model=dict,
)
async def get_case(case_id: str) -> dict:
    case = await firebase_service.get_case(case_id)
    if case is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Case '{case_id}' not found.",
        )
    return case


# ── GET /volunteers ──────────────────────────────────────────

@router.get(
    "/volunteers",
    summary="List available volunteers for Dispatch Agent",
    response_model=list,
)
async def get_volunteers(available: Optional[bool] = Query(default=None)) -> list:
    """
    Returns volunteers from Firebase volunteers/ collection.
    Used exclusively by Dispatch Agent for volunteer matching.
    """
    try:
        if available is True or available is None:
            return await firebase_service.get_available_volunteers()
        # If available=false requested, return all (future extension)
        return await firebase_service.get_available_volunteers()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Volunteer query failed: {exc}",
        )


# ── GET /stats ───────────────────────────────────────────────

@router.get(
    "/stats",
    summary="Case aggregate statistics for dashboard",
    response_model=dict,
)
async def get_stats() -> dict:
    try:
        return await firebase_service.get_case_stats()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Stats query failed: {exc}",
        )
