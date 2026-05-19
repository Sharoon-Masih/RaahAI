# agents/dispatch/agent.py
# ============================================================
# Dispatch Agent — Stage 5 of 5 (FINAL ENGINE)
# Assigns volunteers, generates tickets, SMS, writes to Firebase.
#
# CONTRACT:
#   INPUT:  CaseObject (time_sensitivity populated)
#   OUTPUT: CaseObject with volunteer_assigned, ticket_id,
#           sms_draft, dispatch_status = DISPATCHED set
#
# THIS IS THE ONLY AGENT THAT WRITES TO FIREBASE (via FastAPI).
# ============================================================

from __future__ import annotations

import logging
from datetime import datetime, timezone

from shared.schemas import (
    CaseObject,
    DispatchStatus,
    TraceObject,
    ValidationStatus,
)

logger = logging.getLogger(__name__)


def _generate_ticket_id(case_id: str) -> str:
    ts = int(datetime.now(timezone.utc).timestamp())
    prefix = case_id.replace("-", "")[:6].upper()
    return f"TKT-{ts}-{prefix}"


def _select_volunteer(
    volunteers: list[dict],
    location: str | None,
) -> dict | None:
    """
    Simple volunteer selection:
    1. Try area-based match on location keywords
    2. Fall back to first available volunteer
    """
    if not volunteers:
        return None

    if location:
        loc_lower = location.lower()
        for v in volunteers:
            area = str(v.get("area", "")).lower()
            if any(word in area for word in loc_lower.split()):
                return v

    # Return first available
    return volunteers[0]


async def run(case: CaseObject) -> CaseObject:
    """Run Dispatch Agent on a fully processed CaseObject."""
    from backend.services.gemini_service import run_agent_prompt
    from backend.services import firebase_service
    from agents.dispatch.prompt import DISPATCH_AGENT_SYSTEM_PROMPT

    logger.info(f"[DispatchAgent] Processing case {case.case_id}...")

    # ── Generate ticket ID (always, even for failed cases) ───
    ticket_id = _generate_ticket_id(case.case_id)
    case.ticket_id = ticket_id

    # ── Short-circuit: FAILED / INVALID cases ───────────────
    if (
        case.dispatch_status == DispatchStatus.FAILED
        or case.validation_status == ValidationStatus.INVALID
    ):
        case.dispatch_status = DispatchStatus.FAILED
        case.volunteer_assigned = None
        case.pipeline_stage = "dispatch_agent"
        case.append_trace(TraceObject(
            agent="DispatchAgent",
            timestamp=datetime.now(timezone.utc).isoformat(),
            action="DISPATCH_SKIPPED",
            reasoning=(
                f"Case is FAILED or INVALID. "
                f"Ticket {ticket_id} generated for tracking. No volunteer assigned."
            ),
            tool_calls=[],
            output_summary=f"FAILED. Ticket: {ticket_id}. No dispatch.",
        ))
        await _persist_to_firebase(case, ticket_id, dispatch_log=None)
        return case

    # ── Fetch available volunteers from Firebase ─────────────
    try:
        volunteers = await firebase_service.get_available_volunteers()
    except Exception as exc:
        logger.warning(f"[DispatchAgent] Volunteer fetch failed: {exc}")
        volunteers = []

    selected_volunteer = _select_volunteer(volunteers, case.location_normalized)

    # ── Build Gemini prompt with volunteer context ───────────
    volunteer_context = (
        f"Available volunteers: {[v.get('name') + ' (' + v.get('area', '') + ')' for v in volunteers[:5]]}\n"
        f"Selected volunteer: {selected_volunteer.get('name') if selected_volunteer else 'NONE'}\n"
        f"Applicant area: {case.location_normalized}\n"
        f"Crisis type: {case.crisis_type}\n"
        f"Time sensitivity: {case.time_sensitivity}\n"
        f"Applicant name: {case.applicant_name}\n"
        f"Ticket ID to use: {ticket_id}\n"
        f"Case description: {case.description_en}\n"
    )

    result = await run_agent_prompt(
        system_prompt=DISPATCH_AGENT_SYSTEM_PROMPT,
        user_message=volunteer_context,
        temperature=0.4,
        model_name="gemini-2.5-flash",
    )

    # ── Fallback if Gemini fails ─────────────────────────────
    if result is None:
        volunteer_name = (
            selected_volunteer.get("name", "Volunteer")
            if selected_volunteer else "NO_VOLUNTEER_FOUND"
        )
        result = {
            "ticket_id": ticket_id,
            "volunteer_id": selected_volunteer.get("id") if selected_volunteer else None,
            "volunteer_name": volunteer_name,
            "sms_draft": (
                f"Assalam o Alaikum! Aapki application accept ho gayi. "
                f"Volunteer {volunteer_name} aap ke paas aa rahe hain. "
                f"Ticket: {ticket_id}. RaahAI Team."
            )[:160],
            "volunteer_instruction": (
                f"Please visit {case.location_normalized or 'applicant location'} "
                f"to assist with {case.crisis_type} case. Ticket: {ticket_id}."
            ),
            "dispatch_status": "DISPATCHED" if selected_volunteer else "PENDING_MANUAL",
            "reasoning": "Fallback dispatch — Gemini unavailable.",
        }

    # ── Apply results to CaseObject ──────────────────────────
    case.volunteer_assigned = result.get("volunteer_name")
    case.sms_draft = result.get("sms_draft")

    status_str = result.get("dispatch_status", "PENDING_MANUAL")
    try:
        case.dispatch_status = DispatchStatus(status_str)
    except ValueError:
        case.dispatch_status = DispatchStatus.PENDING_MANUAL

    case.pipeline_stage = "dispatch_agent"

    # ── Build dispatch log for Firebase ─────────────────────
    dispatch_log = {
        "case_id": case.case_id,
        "ticket_id": ticket_id,
        "volunteer_id": result.get("volunteer_id"),
        "volunteer_name": case.volunteer_assigned,
        "severity_score": case.severity_score,
        "severity_level": str(case.severity_level.value) if case.severity_level else None,
        "time_sensitivity": str(case.time_sensitivity.value) if case.time_sensitivity else None,
        "crisis_type": case.crisis_type,
        "dispatched_at": datetime.now(timezone.utc).isoformat(),
        "sms_draft": case.sms_draft,
        "action_summary": result.get("reasoning", ""),
        "volunteer_instruction": result.get("volunteer_instruction", ""),
    }

    # ── Append trace ─────────────────────────────────────────
    tool_calls = [
        "firebase_firestore:volunteers_query (via FastAPI)",
        "gemini_api:sms_generation",
        "firebase_firestore:dispatch_log_insert (via FastAPI)",
        "firebase_firestore:case_update (via FastAPI)",
    ]
    case.append_trace(TraceObject(
        agent="DispatchAgent",
        timestamp=datetime.now(timezone.utc).isoformat(),
        action=f"Full dispatch executed: {case.dispatch_status}",
        reasoning=(
            f"Case {case.case_id}: {case.severity_level} severity "
            f"({case.severity_score}/10), time sensitivity: {case.time_sensitivity}. "
            f"Volunteer: {case.volunteer_assigned}. Ticket: {ticket_id}. "
            f"Reasoning: {result.get('reasoning', '')}"
        ),
        tool_calls=tool_calls,
        output_summary=(
            f"{case.dispatch_status}. Volunteer: {case.volunteer_assigned}. "
            f"Ticket: {ticket_id}. SMS drafted. Firebase logged."
        ),
    ))

    # ── Persist to Firebase ──────────────────────────────────
    await _persist_to_firebase(case, ticket_id, dispatch_log)

    logger.info(
        f"[DispatchAgent] Done. case_id={case.case_id} "
        f"status={case.dispatch_status} volunteer={case.volunteer_assigned}"
    )
    return case


async def _persist_to_firebase(
    case: CaseObject,
    ticket_id: str,
    dispatch_log: dict | None,
) -> None:
    """Write final case state and dispatch log to Firebase via firebase_service."""
    from backend.services import firebase_service

    try:
        # Update case document
        await firebase_service.update_case_fields(case.case_id, {
            "dispatch_status": case.dispatch_status.value,
            "pipeline_stage": case.pipeline_stage,
            "volunteer_assigned": case.volunteer_assigned,
            "ticket_id": ticket_id,
            "sms_draft": case.sms_draft,
            "agent_trace": [
                t.model_dump(mode="json") if hasattr(t, "model_dump") else t
                for t in case.agent_trace
            ],
        })
        logger.info(f"[DispatchAgent] Firebase case/{case.case_id} updated.")
    except Exception as exc:
        logger.error(f"[DispatchAgent] Firebase case update failed: {exc}")

    if dispatch_log:
        try:
            await firebase_service.write_dispatch_log(ticket_id, dispatch_log)
            logger.info(f"[DispatchAgent] Firebase dispatch_logs/{ticket_id} written.")
        except Exception as exc:
            logger.error(f"[DispatchAgent] Firebase dispatch log write failed: {exc}")
