# agents/intake/agent.py
# ============================================================
# Intake Agent — Stage 1 of 5
# Converts raw unstructured text into a structured CaseObject.
# Uses Gemini with INTAKE_AGENT_SYSTEM_PROMPT.
#
# CONTRACT:
#   INPUT:  raw string (email / form / CSV / WhatsApp)
#   OUTPUT: CaseObject (validated by shared/schemas.py)
#
# NEVER modifies validation_status, severity, or dispatch fields.
# ALWAYS produces a CaseObject — even for broken/empty input.
# ============================================================

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from shared.schemas import CaseObject, DispatchStatus, TraceObject

logger = logging.getLogger(__name__)


async def run(raw_input: str, submission_source: str = "web_form") -> CaseObject:
    """
    Main entry point for the Intake Agent.

    Args:
        raw_input: The unstructured text from any source.
        submission_source: Where the input came from.

    Returns:
        A fully structured CaseObject ready for the Validation Agent.
    """
    from backend.services.gemini_service import run_intake_agent

    logger.info(f"[IntakeAgent] Processing input ({len(raw_input)} chars)...")

    # ── Guard: Empty input ───────────────────────────────────
    if not raw_input or not raw_input.strip():
        return _build_failed_case(
            raw_input="",
            reason="Input was empty or whitespace-only — no content to parse.",
            submission_source=submission_source,
        )

    # ── Call Gemini ──────────────────────────────────────────
    result = await run_intake_agent(raw_input)

    # ── Guard: Total Gemini failure ──────────────────────────
    if result is None:
        return _build_failed_case(
            raw_input=raw_input,
            reason="Gemini API failed to return a parseable response after retries.",
            submission_source=submission_source,
        )

    # ── Enforce contract: override fields Intake must not set ─
    result = _enforce_intake_contract(result, raw_input, submission_source)

    # ── Validate against Pydantic schema ────────────────────
    try:
        case = CaseObject(**result)
    except Exception as exc:
        logger.error(f"[IntakeAgent] CaseObject validation failed: {exc}")
        return _build_failed_case(
            raw_input=raw_input,
            reason=f"Schema validation error after Gemini parse: {exc}",
            submission_source=submission_source,
        )

    logger.info(
        f"[IntakeAgent] Done. case_id={case.case_id} "
        f"stage={case.pipeline_stage} crisis={case.crisis_type}"
    )
    return case


def _enforce_intake_contract(data: dict, raw_input: str, submission_source: str) -> dict:
    """
    Enforce the Intake Agent output contract on the Gemini result.
    Sets mandatory fields, nullifies downstream fields, preserves original input.
    """
    # Generate fresh case_id if missing or invalid
    case_id = data.get("case_id", "")
    try:
        uuid.UUID(str(case_id))
    except (ValueError, AttributeError):
        case_id = str(uuid.uuid4())
    data["case_id"] = case_id

    # Pipeline stage from Gemini or default
    if data.get("pipeline_stage") not in ("INTAKE_COMPLETE", "INTAKE_FAILED"):
        data["pipeline_stage"] = "INTAKE_COMPLETE"

    # dispatch_status: only PENDING or FAILED allowed at intake
    if data.get("dispatch_status") not in ("PENDING", "FAILED"):
        data["dispatch_status"] = "PENDING"

    # Preserve original input exactly (never let Gemini modify it)
    if raw_input:
        data["description_original"] = raw_input

    # Nullify ALL downstream fields — Intake Agent never sets these
    downstream_nulls = [
        "validation_status", "severity_score", "severity_level",
        "time_sensitivity", "volunteer_assigned", "ticket_id",
        "delay_consequence", "location_risk_factor", "key_insight",
        "scoring_breakdown",
    ]
    for field in downstream_nulls:
        data[field] = None

    # Default array fields
    for arr_field in ("validation_reasons", "fraud_signals", "agent_trace"):
        if not isinstance(data.get(arr_field), list):
            data[arr_field] = []

    # compound_crisis_detected — always False at intake
    data["compound_crisis_detected"] = False

    # submission_source
    data["submission_source"] = submission_source

    # Ensure agent_trace has at least one IntakeAgent entry
    intake_entries = [
        t for t in data["agent_trace"]
        if isinstance(t, dict) and t.get("agent") == "IntakeAgent"
    ]
    if not intake_entries:
        data["agent_trace"].append({
            "agent": "IntakeAgent",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "action": "RAW_INPUT_PARSED",
            "reasoning": "Trace entry added by enforcement layer — Gemini omitted trace.",
            "tool_calls": [],
            "output_summary": f"case_id={data['case_id']} parsed.",
        })

    return data


def _build_failed_case(
    raw_input: str,
    reason: str,
    submission_source: str,
) -> CaseObject:
    """
    Golden Rule: NEVER drop a case.
    Returns a FAILED CaseObject for any broken / empty input.
    """
    logger.warning(f"[IntakeAgent] INTAKE_FAILED: {reason}")

    trace = TraceObject(
        agent="IntakeAgent",
        timestamp=datetime.now(timezone.utc).isoformat(),
        action="INTAKE_FAILED",
        reasoning=reason,
        tool_calls=[],
        output_summary="INTAKE_FAILED — unreadable or empty input.",
    )

    return CaseObject(
        case_id=str(uuid.uuid4()),
        description_original=raw_input,
        dispatch_status=DispatchStatus.FAILED,
        pipeline_stage="INTAKE_FAILED",
        submission_source=submission_source,
        agent_trace=[trace],
    )
