# backend/routes/applications.py
# ============================================================
# Application Management APIs
# Provides filtering, sorting, searching, and pagination.
# ============================================================

from __future__ import annotations
import logging
from datetime import datetime
from typing import Optional, List

from fastapi import APIRouter, HTTPException, Query, Header, status
from backend.services import firebase_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/applications", tags=["Applications"])

@router.get(
    "",
    summary="List and filter applications for an NGO",
    response_model=dict,
)
async def list_applications(
    assigned_ngo_id: str = Header(..., description="The ID of the assigned NGO"),
    status_filter: Optional[str] = Query(None, alias="status", description="PENDING, PROCESSING, DISPATCHED, FAILED"),
    severity: Optional[str] = Query(None, description="LOW, MEDIUM, HIGH, CRITICAL"),
    date_from: Optional[str] = Query(None, description="ISO8601 date string"),
    date_to: Optional[str] = Query(None, description="ISO8601 date string"),
    location: Optional[str] = Query(None, description="Substring match on location_normalized"),
    crisis_type: Optional[str] = Query(None, description="Filter by crisis_type"),
    has_volunteer: Optional[bool] = Query(None, description="True if volunteer_assigned is populated"),
    search_applicant: Optional[str] = Query(None, description="Substring match on applicant_name"),
    search_ticket: Optional[str] = Query(None, description="Exact/Substring match on ticket_id"),
    search_phone: Optional[str] = Query(None, description="Exact/Substring match on phone"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    sort_by: str = Query("latest", description="urgency, severity, latest, unresolved"),
) -> dict:
    """
    Returns a paginated list of CaseObjects matching the provided filters.
    In-memory filtering is applied to support complex multi-field searches.
    """
    try:
        cases = await firebase_service.list_cases_for_ngo(assigned_ngo_id)
    except Exception as exc:
        logger.error(f"[Applications] Firebase read failed: {exc}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to fetch cases from database.",
        )

    filtered_cases = []

    # ── In-Memory Filtering ──
    for case in cases:
        # Status
        if status_filter and case.get("dispatch_status") != status_filter:
            continue
            
        # Severity
        if severity and case.get("severity_level") != severity:
            continue
            
        # Crisis Type
        if crisis_type and case.get("crisis_type") != crisis_type:
            continue
            
        # Volunteer Assigned
        v_assigned = case.get("volunteer_assigned")
        if has_volunteer is True and not v_assigned:
            continue
        if has_volunteer is False and v_assigned:
            continue
            
        # Location (substring)
        if location:
            loc = case.get("location_normalized", "") or ""
            if location.lower() not in loc.lower():
                continue
                
        # Applicant Search (substring)
        if search_applicant:
            app_name = case.get("applicant_name", "") or ""
            if search_applicant.lower() not in app_name.lower():
                continue
                
        # Ticket Search (substring)
        if search_ticket:
            tkt = case.get("ticket_id", "") or ""
            if search_ticket.lower() not in tkt.lower():
                continue
                
        # Phone Search (substring)
        if search_phone:
            ph = case.get("phone", "") or ""
            if search_phone not in ph:
                continue

        # Date Filtering
        # Assume creation date is the first trace timestamp or fallback to current time for logic
        # If no trace, skip date filter or include it based on requirement. We will include.
        if date_from or date_to:
            traces = case.get("agent_trace", [])
            case_ts = None
            if traces and traces[0].get("timestamp"):
                try:
                    case_ts = datetime.fromisoformat(traces[0]["timestamp"].replace("Z", "+00:00"))
                except ValueError:
                    pass
            
            if case_ts:
                if date_from:
                    try:
                        df = datetime.fromisoformat(date_from.replace("Z", "+00:00"))
                        if case_ts < df:
                            continue
                    except ValueError:
                        pass
                if date_to:
                    try:
                        dt = datetime.fromisoformat(date_to.replace("Z", "+00:00"))
                        if case_ts > dt:
                            continue
                    except ValueError:
                        pass

        filtered_cases.append(case)

    # ── Sorting ──
    # Helper to get timestamp
    def get_ts(c):
        traces = c.get("agent_trace", [])
        if traces and traces[0].get("timestamp"):
            return traces[0]["timestamp"]
        return ""

    if sort_by == "severity":
        # Sort by severity_score DESC
        filtered_cases.sort(key=lambda c: c.get("severity_score") or 0.0, reverse=True)
    elif sort_by == "urgency":
        # Custom logic: map time_sensitivity to a numeric value
        # IMMEDIATE=3, TODAY=2, THIS_WEEK=1, None=0
        urgency_map = {"IMMEDIATE": 3, "TODAY": 2, "THIS_WEEK": 1}
        filtered_cases.sort(
            key=lambda c: urgency_map.get(c.get("time_sensitivity", ""), 0), 
            reverse=True
        )
    elif sort_by == "unresolved":
        # Show pending/processing first, then others
        def unresolved_key(c):
            st = c.get("dispatch_status")
            if st in ("PENDING", "PROCESSING"):
                return 1
            return 0
        # Sort by unresolved (1 first), then latest
        filtered_cases.sort(key=lambda c: (unresolved_key(c), get_ts(c)), reverse=True)
    else:
        # Default: latest
        filtered_cases.sort(key=lambda c: get_ts(c), reverse=True)

    # ── Pagination ──
    total_records = len(filtered_cases)
    total_pages = (total_records + limit - 1) // limit
    
    # Ensure page is within bounds
    if page > total_pages and total_pages > 0:
        page = total_pages

    start_idx = (page - 1) * limit
    end_idx = start_idx + limit
    
    paginated_data = filtered_cases[start_idx:end_idx]

    return {
        "pagination": {
            "page": page,
            "limit": limit,
            "total_records": total_records,
            "total_pages": total_pages,
            "has_next": page < total_pages,
            "has_prev": page > 1
        },
        "data": paginated_data
    }
