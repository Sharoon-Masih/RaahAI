# backend/routes/dashboard.py
# ============================================================
# Dashboard Summary APIs
# Provides aggregated statistics for the NGO dashboard.
# ============================================================

from __future__ import annotations
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Header, status
from backend.services import firebase_service
from shared.schemas import DispatchStatus

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])

@router.get(
    "/summary",
    summary="Get aggregated dashboard statistics for an NGO",
    response_model=dict,
)
async def get_dashboard_summary(
    assigned_ngo_id: str = Header(..., description="The ID of the assigned NGO"),
) -> dict:
    """
    Returns total assigned cases, active, dispatched, pending, critical, medium, 
    resolved, rejected cases, volunteer availability, response rate, 
    average resolution time, today/weekly/monthly cases, and emergency trends.
    """
    try:
        cases = await firebase_service.list_cases_for_ngo(assigned_ngo_id)
    except Exception as exc:
        logger.error(f"[Dashboard] Firebase read failed: {exc}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to fetch cases from database.",
        )

    # Initialize counters
    total_assigned = len(cases)
    
    active_cases = 0
    dispatched_cases = 0
    pending_cases = 0
    resolved_cases = 0
    rejected_cases = 0
    
    severity_breakdown = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    emergency_trends = {}
    
    now = datetime.now(timezone.utc)
    today = now.date()
    today_cases = 0
    yesterday_cases = 0
    weekly_cases = 0
    last_week_cases = 0
    monthly_cases = 0
    last_month_cases = 0
    
    # Daily intake for the last 14 days (index 13 = today, index 0 = 13 days ago)
    daily_intake_map = { (today - timedelta(days=i)): 0 for i in range(14) }
    
    total_resolution_hours = 0.0
    resolved_count_for_avg = 0
    
    recent_critical_cases = []

    for case in cases:
        # Status aggregation
        d_status = case.get("dispatch_status", "PENDING")
        if d_status in ("PENDING", "PROCESSING"):
            active_cases += 1
        if d_status == "DISPATCHED":
            dispatched_cases += 1
            resolved_cases += 1
        if d_status == "PENDING":
            pending_cases += 1
        if d_status in ("FAILED", "INVALID"):
            rejected_cases += 1
            
        # Severity aggregation
        sev = case.get("severity_level", "").lower()
        if sev in severity_breakdown:
            severity_breakdown[sev] += 1
            
        # Trends
        crisis = case.get("crisis_type")
        if crisis:
            crisis = crisis.lower()
            emergency_trends[crisis] = emergency_trends.get(crisis, 0) + 1
            
        # Time Metrics and Daily Intake
        traces = case.get("agent_trace", [])
        if traces:
            try:
                # First trace timestamp is usually creation time
                first_ts_str = traces[0].get("timestamp")
                if first_ts_str:
                    first_ts = datetime.fromisoformat(first_ts_str.replace("Z", "+00:00"))
                    case_date = first_ts.date()
                    delta_days = (today - case_date).days
                    
                    # Exact time comparisons
                    if delta_days == 0:
                        today_cases += 1
                    elif delta_days == 1:
                        yesterday_cases += 1
                        
                    if 0 <= delta_days <= 6:
                        weekly_cases += 1
                    elif 7 <= delta_days <= 13:
                        last_week_cases += 1
                        
                    if 0 <= delta_days <= 29:
                        monthly_cases += 1
                    elif 30 <= delta_days <= 59:
                        last_month_cases += 1
                        
                    # Daily intake array (14 days)
                    if 0 <= delta_days < 14:
                        daily_intake_map[case_date] += 1
                        
                # If resolved (DISPATCHED), calculate resolution time
                if d_status == "DISPATCHED":
                    last_ts_str = traces[-1].get("timestamp")
                    if last_ts_str and first_ts_str:
                        last_ts = datetime.fromisoformat(last_ts_str.replace("Z", "+00:00"))
                        resolution_hours = (last_ts - first_ts).total_seconds() / 3600.0
                        if resolution_hours >= 0:
                            total_resolution_hours += resolution_hours
                            resolved_count_for_avg += 1
            except Exception:
                pass
                
        # Capture critical cases for the recent list
        if sev in ("high", "critical"):
            # try to parse the timestamp for sorting
            first_ts = datetime.min.replace(tzinfo=timezone.utc)
            if traces:
                ts_str = traces[0].get("timestamp")
                if ts_str:
                    try:
                        first_ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                    except:
                        pass
            
            recent_critical_cases.append({
                "applicant": case.get("applicant_name", "Unknown"),
                "crisis": case.get("crisis_type", "Unknown").title(),
                "score": case.get("severity_score", 0.0),
                "status": d_status.title(),
                "location": case.get("location_normalized", "Unknown"),
                "_ts": first_ts
            })

    avg_resolution = 0.0
    if resolved_count_for_avg > 0:
        avg_resolution = round(total_resolution_hours / resolved_count_for_avg, 2)
        
    response_rate = 0.0
    if total_assigned > 0:
        # e.g., anything not strictly pending means we responded
        responded = total_assigned - pending_cases
        response_rate = round((responded / total_assigned) * 100, 2)

    # Fetch volunteers for metrics
    volunteer_availability_list = []
    try:
        volunteers = await firebase_service.get_available_volunteers()
        v_available = len(volunteers)
        v_total = v_available + 38 # placeholder
        for v in volunteers[:5]:
            volunteer_availability_list.append({
                "name": v.get("name", "Unknown"),
                "location": v.get("location", "Unknown"),
                "is_available": v.get("is_available", True)
            })
    except Exception:
        v_available = 0
        v_total = 0
        
    # Sort and take top 5 critical cases
    recent_critical_cases.sort(key=lambda x: x["_ts"], reverse=True)
    recent_critical_cases = recent_critical_cases[:5]
    for c in recent_critical_cases:
        c.pop("_ts")
        
    # Build daily intake array (ordered from oldest to newest)
    daily_intake = []
    for i in range(13, -1, -1):
        d = today - timedelta(days=i)
        daily_intake.append(daily_intake_map[d])

    return {
        "cases_overview": {
            "total_assigned": total_assigned,
            "active": active_cases,
            "dispatched": dispatched_cases,
            "pending": pending_cases,
            "resolved": resolved_cases,
            "rejected": rejected_cases
        },
        "severity_breakdown": severity_breakdown,
        "volunteer_metrics": {
            "total_volunteers": v_total,
            "available": v_available,
            "busy": v_total - v_available
        },
        "performance_metrics": {
            "response_rate_percentage": response_rate,
            "average_resolution_time_hours": avg_resolution
        },
        "time_metrics": {
            "today_cases": today_cases,
            "yesterday_cases": yesterday_cases,
            "weekly_cases": weekly_cases,
            "last_week_cases": last_week_cases,
            "monthly_cases": monthly_cases,
            "last_month_cases": last_month_cases,
            "daily_intake": daily_intake
        },
        "recent_critical_cases": recent_critical_cases,
        "volunteer_availability_list": volunteer_availability_list,
        "emergency_trends": emergency_trends
    }
