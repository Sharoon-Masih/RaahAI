# agents/impact/agent.py
# ============================================================
# Impact Agent — Stage 4 of 5
# Predicts time sensitivity and delay consequences.
#
# CONTRACT:
#   INPUT:  CaseObject (severity_score + severity_level populated)
#   OUTPUT: CaseObject with time_sensitivity + delay_consequence set
# ============================================================

from __future__ import annotations

import logging
from datetime import datetime, timezone

from shared.schemas import (
    CaseObject,
    DispatchStatus,
    SeverityLevel,
    TimeSensitivity,
    TraceObject,
)

logger = logging.getLogger(__name__)


def _deterministic_time_sensitivity(case: CaseObject) -> TimeSensitivity:
    """Apply deterministic rules before Gemini."""
    if case.medical_emergency or case.severity_level == SeverityLevel.CRITICAL:
        return TimeSensitivity.IMMEDIATE
    if case.severity_score is not None and case.severity_score >= 8.0:
        return TimeSensitivity.IMMEDIATE
    if case.severity_level == SeverityLevel.HIGH:
        return TimeSensitivity.TODAY
    if case.severity_score is not None and case.severity_score >= 6.0:
        return TimeSensitivity.TODAY
    if case.severity_level == SeverityLevel.MEDIUM:
        return TimeSensitivity.TODAY
    return TimeSensitivity.THIS_WEEK


async def run(case: CaseObject) -> CaseObject:
    """Run Impact Agent on a severity-scored CaseObject."""
    from backend.services.gemini_service import run_agent_prompt
    from agents.impact.prompt import IMPACT_AGENT_SYSTEM_PROMPT

    logger.info(f"[ImpactAgent] Processing case {case.case_id}...")

    # ── Pass-through: FAILED cases ───────────────────────────
    if case.dispatch_status == DispatchStatus.FAILED:
        case.time_sensitivity = TimeSensitivity.THIS_WEEK
        case.pipeline_stage = "impact_agent"
        case.append_trace(TraceObject(
            agent="ImpactAgent",
            timestamp=datetime.now(timezone.utc).isoformat(),
            action="PASS_THROUGH",
            reasoning="Case has FAILED status. Assigning default time_sensitivity.",
            tool_calls=[],
            output_summary="Pass-through. time_sensitivity = THIS_WEEK (default).",
        ))
        return case

    # ── Deterministic pre-classification ─────────────────────
    deterministic_ts = _deterministic_time_sensitivity(case)

    # ── Call Gemini for consequence modeling ─────────────────
    user_message = (
        f"Predict timing urgency for this welfare case:\n\n"
        f"Severity Score: {case.severity_score}\n"
        f"Severity Level: {case.severity_level}\n"
        f"Medical Emergency: {case.medical_emergency}\n"
        f"Has Children: {case.has_children}\n"
        f"Income (PKR/month): {case.income_monthly}\n"
        f"Location: {case.location_normalized}\n"
        f"Crisis Type: {case.crisis_type}\n"
        f"Description: {case.description_en}\n"
        f"Key Insight from Severity Agent: {case.key_insight}\n"
    )

    result = await run_agent_prompt(
        system_prompt=IMPACT_AGENT_SYSTEM_PROMPT,
        user_message=user_message,
        temperature=0.3,
    )

    # ── Fallback if Gemini fails ─────────────────────────────
    if result is None:
        result = {
            "time_sensitivity": deterministic_ts.value,
            "delay_consequence": (
                "If not addressed promptly, this case may escalate. "
                "Consequence modeling unavailable — deterministic rules applied."
            ),
            "location_risk_factor": "unknown",
            "reasoning": "Gemini unavailable. Deterministic rules applied based on severity.",
        }

    # ── Apply results ─────────────────────────────────────────
    ts_str = result.get("time_sensitivity", deterministic_ts.value)
    try:
        case.time_sensitivity = TimeSensitivity(ts_str)
    except ValueError:
        case.time_sensitivity = deterministic_ts

    case.delay_consequence = result.get("delay_consequence")
    case.location_risk_factor = result.get("location_risk_factor", "unknown")
    case.pipeline_stage = "impact_agent"

    reasoning = result.get("reasoning", "No reasoning provided.")

    # ── Append trace ─────────────────────────────────────────
    case.append_trace(TraceObject(
        agent="ImpactAgent",
        timestamp=datetime.now(timezone.utc).isoformat(),
        action=f"Time sensitivity: {case.time_sensitivity}",
        reasoning=f"{reasoning}. Consequence: {case.delay_consequence}",
        tool_calls=["gemini_api"],
        output_summary=(
            f"Must act: {case.time_sensitivity}. "
            f"Location risk: {case.location_risk_factor}."
        ),
    ))

    logger.info(
        f"[ImpactAgent] Done. case_id={case.case_id} "
        f"time_sensitivity={case.time_sensitivity}"
    )
    return case
