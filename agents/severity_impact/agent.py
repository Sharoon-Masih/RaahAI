# agents/severity_impact/agent.py
# ============================================================
# Severity & Impact Agent — Stage 3 of 5
# Scores urgency of a validated case and predicts time sensitivity.
#
# CONTRACT:
#   INPUT:  CaseObject (validation_status populated)
#   OUTPUT: CaseObject with severity_score, severity_level, 
#           time_sensitivity, delay_consequence set
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
    ValidationStatus,
)

logger = logging.getLogger(__name__)

_BASE_SCORES = {
    "food": 5.0,
    "medical": 6.0,
    "emergency_cash": 4.5,
    "education": 3.5,
    "flood_relief": 6.5,
}

def _deterministic_score_and_impact(case: CaseObject) -> tuple[float, list[dict], TimeSensitivity]:
    """Compute fallback score and time sensitivity."""
    base = _BASE_SCORES.get(str(case.crisis_type), 4.0)
    additions = []

    if case.income_monthly == 0:
        additions.append({"reason": "Zero income", "points": 2.5})
    elif case.income_monthly < 5000:
        additions.append({"reason": "Income < 5000 PKR", "points": 1.5})

    if case.medical_emergency:
        additions.append({"reason": "Medical emergency flagged", "points": 2.5})

    if case.has_children:
        additions.append({"reason": "Has children", "points": 1.5})

    if case.family_size >= 8:
        additions.append({"reason": "Large family (8+)", "points": 1.5})
    elif case.family_size >= 5:
        additions.append({"reason": "Large family (5+)", "points": 1.0})

    score = min(10.0, max(1.0, base + sum(a["points"] for a in additions)))
    
    level = _level_from_score(score)
    if case.medical_emergency or level == SeverityLevel.CRITICAL or score >= 8.0:
        ts = TimeSensitivity.IMMEDIATE
    elif level in [SeverityLevel.HIGH, SeverityLevel.MEDIUM] or score >= 6.0:
        ts = TimeSensitivity.TODAY
    else:
        ts = TimeSensitivity.THIS_WEEK

    return score, additions, ts


def _level_from_score(score: float) -> SeverityLevel:
    if score >= 8.0:
        return SeverityLevel.CRITICAL
    if score >= 6.0:
        return SeverityLevel.HIGH
    if score >= 4.0:
        return SeverityLevel.MEDIUM
    return SeverityLevel.LOW


async def run(case: CaseObject) -> CaseObject:
    """Run Severity & Impact Agent on a validated CaseObject."""
    from backend.services.gemini_service import run_agent_prompt
    from agents.severity_impact.prompt import SEVERITY_IMPACT_AGENT_SYSTEM_PROMPT

    logger.info(f"[SeverityImpactAgent] Processing case {case.case_id}...")

    # ── Pass-through: INVALID or FAILED cases ───────────────
    if (
        case.dispatch_status == DispatchStatus.FAILED
        or case.validation_status == ValidationStatus.INVALID
    ):
        case.severity_score = 0.0
        case.severity_level = SeverityLevel.LOW
        case.time_sensitivity = TimeSensitivity.THIS_WEEK
        case.key_insight = "Case is INVALID or FAILED — severity/impact not scored."
        case.pipeline_stage = "severity_impact_agent"
        case.append_trace(TraceObject(
            agent="SeverityImpactAgent",
            timestamp=datetime.now(timezone.utc).isoformat(),
            action="SKIPPED — INVALID/FAILED case",
            reasoning="Validation status is INVALID or dispatch_status is FAILED.",
            tool_calls=[],
            output_summary="Score: 0.0. Level: LOW. TS: THIS_WEEK. Skipped.",
        ))
        return case

    # ── Build user message ───────────────────────────────────
    user_message = (
        f"Score this welfare case and predict impact:\n\n"
        f"Crisis Type: {case.crisis_type}\n"
        f"Family Size: {case.family_size}\n"
        f"Monthly Income (PKR): {case.income_monthly}\n"
        f"Medical Emergency: {case.medical_emergency}\n"
        f"Has Children: {case.has_children}\n"
        f"Description (English): {case.description_en}\n"
        f"Description (Original): {case.description_original}\n"
        f"Location: {case.location_normalized}\n"
        f"Validation Status: {case.validation_status}\n"
    )

    result = await run_agent_prompt(
        system_prompt=SEVERITY_IMPACT_AGENT_SYSTEM_PROMPT,
        user_message=user_message,
        temperature=0.2,
        model_name="gemini-2.5-flash",
    )

    # ── Deterministic fallback if Gemini completely fails ────
    if result is None:
        score, additions, ts = _deterministic_score_and_impact(case)
        result = {
            "severity_score": score,
            "severity_level": _level_from_score(score).value,
            "scoring_breakdown": {
                "base_score": _BASE_SCORES.get(str(case.crisis_type), 4.0),
                "additions": additions,
                "final_score": score,
            },
            "key_insight": "Deterministic scoring used — Gemini unavailable.",
            "compound_crisis_detected": case.medical_emergency and case.income_monthly == 0,
            "time_sensitivity": ts.value,
            "delay_consequence": "If not addressed promptly, this case may escalate.",
            "location_risk_factor": "unknown"
        }

    # ── Apply results ─────────────────────────────────────────
    raw_score = float(result.get("severity_score", 5.0))
    case.severity_score = min(10.0, max(1.0, raw_score))
    try:
        case.severity_level = SeverityLevel(result.get("severity_level", "MEDIUM"))
    except ValueError:
        case.severity_level = _level_from_score(case.severity_score)
        
    try:
        case.time_sensitivity = TimeSensitivity(result.get("time_sensitivity", "THIS_WEEK"))
    except ValueError:
        case.time_sensitivity = TimeSensitivity.THIS_WEEK

    case.key_insight = result.get("key_insight")
    case.scoring_breakdown = result.get("scoring_breakdown")
    case.compound_crisis_detected = bool(result.get("compound_crisis_detected", False))
    case.delay_consequence = result.get("delay_consequence")
    case.location_risk_factor = result.get("location_risk_factor", "unknown")
    case.pipeline_stage = "severity_impact_agent"

    # ── Append trace ─────────────────────────────────────────
    case.append_trace(TraceObject(
        agent="SeverityImpactAgent",
        timestamp=datetime.now(timezone.utc).isoformat(),
        action=f"Severity: {case.severity_score}/10 ({case.severity_level}) | TS: {case.time_sensitivity}",
        reasoning=f"{case.key_insight}. Consequence: {case.delay_consequence}",
        tool_calls=["gemini_api"],
        output_summary=(
            f"Score: {case.severity_score}. Level: {case.severity_level}. "
            f"TS: {case.time_sensitivity}."
        ),
    ))

    logger.info(
        f"[SeverityImpactAgent] Done. case_id={case.case_id} "
        f"score={case.severity_score} level={case.severity_level} ts={case.time_sensitivity}"
    )
    return case
