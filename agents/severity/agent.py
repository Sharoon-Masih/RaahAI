# agents/severity/agent.py
# ============================================================
# Severity Agent — Stage 3 of 5
# Scores urgency of a validated case (1.0 – 10.0).
#
# CONTRACT:
#   INPUT:  CaseObject (validation_status populated)
#   OUTPUT: CaseObject with severity_score + severity_level set
# ============================================================

from __future__ import annotations

import logging
from datetime import datetime, timezone

from shared.schemas import (
    CaseObject,
    DispatchStatus,
    SeverityLevel,
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


def _deterministic_score(case: CaseObject) -> tuple[float, list[dict]]:
    """Compute a fallback score using the rubric without Gemini."""
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

    total = min(10.0, max(1.0, base + sum(a["points"] for a in additions)))
    return total, additions


def _level_from_score(score: float) -> SeverityLevel:
    if score >= 8.0:
        return SeverityLevel.CRITICAL
    if score >= 6.0:
        return SeverityLevel.HIGH
    if score >= 4.0:
        return SeverityLevel.MEDIUM
    return SeverityLevel.LOW


async def run(case: CaseObject) -> CaseObject:
    """Run Severity Agent on a validated CaseObject."""
    from backend.services.gemini_service import run_agent_prompt
    from agents.severity.prompt import SEVERITY_AGENT_SYSTEM_PROMPT

    logger.info(f"[SeverityAgent] Processing case {case.case_id}...")

    # ── Pass-through: INVALID or FAILED cases ───────────────
    if (
        case.dispatch_status == DispatchStatus.FAILED
        or case.validation_status == ValidationStatus.INVALID
    ):
        case.severity_score = 0.0
        case.severity_level = SeverityLevel.LOW
        case.key_insight = "Case is INVALID or FAILED — severity not scored."
        case.pipeline_stage = "severity_agent"
        case.append_trace(TraceObject(
            agent="SeverityAgent",
            timestamp=datetime.now(timezone.utc).isoformat(),
            action="SKIPPED — INVALID/FAILED case",
            reasoning="Validation status is INVALID or dispatch_status is FAILED.",
            tool_calls=[],
            output_summary="Score: 0.0. Level: LOW. Skipped.",
        ))
        return case

    # ── Build user message ───────────────────────────────────
    user_message = (
        f"Score this welfare case:\n\n"
        f"Crisis Type: {case.crisis_type}\n"
        f"Family Size: {case.family_size}\n"
        f"Monthly Income (PKR): {case.income_monthly}\n"
        f"Medical Emergency: {case.medical_emergency}\n"
        f"Has Children: {case.has_children}\n"
        f"Description (English): {case.description_en}\n"
        f"Description (Original): {case.description_original}\n"
        f"Validation Status: {case.validation_status}\n"
    )

    result = await run_agent_prompt(
        system_prompt=SEVERITY_AGENT_SYSTEM_PROMPT,
        user_message=user_message,
        temperature=0.2,
    )

    # ── Retry with simplified prompt if first attempt fails ──
    if result is None:
        simple_prompt = (
            f"Score severity 1-10 for: crisis={case.crisis_type}, "
            f"income={case.income_monthly}, children={case.has_children}, "
            f"medical={case.medical_emergency}, family={case.family_size}. "
            "Return JSON: {\"severity_score\": X, \"severity_level\": \"X\", "
            "\"scoring_breakdown\": {}, \"key_insight\": \"X\", \"compound_crisis_detected\": false}"
        )
        result = await run_agent_prompt(
            system_prompt=SEVERITY_AGENT_SYSTEM_PROMPT,
            user_message=simple_prompt,
            temperature=0.1,
        )

    # ── Deterministic fallback if Gemini completely fails ────
    if result is None:
        score, additions = _deterministic_score(case)
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
        }

    # ── Apply results ─────────────────────────────────────────
    raw_score = float(result.get("severity_score", 5.0))
    case.severity_score = min(10.0, max(1.0, raw_score))
    try:
        case.severity_level = SeverityLevel(result.get("severity_level", "MEDIUM"))
    except ValueError:
        case.severity_level = _level_from_score(case.severity_score)

    case.key_insight = result.get("key_insight")
    case.scoring_breakdown = result.get("scoring_breakdown")
    case.compound_crisis_detected = bool(result.get("compound_crisis_detected", False))
    case.pipeline_stage = "severity_agent"

    # ── Append trace ─────────────────────────────────────────
    case.append_trace(TraceObject(
        agent="SeverityAgent",
        timestamp=datetime.now(timezone.utc).isoformat(),
        action=f"Severity scored: {case.severity_score}/10 ({case.severity_level})",
        reasoning=f"{case.key_insight}. Breakdown: {case.scoring_breakdown}",
        tool_calls=["gemini_api"],
        output_summary=(
            f"Score: {case.severity_score}. Level: {case.severity_level}. "
            f"Compound crisis: {case.compound_crisis_detected}."
        ),
    ))

    logger.info(
        f"[SeverityAgent] Done. case_id={case.case_id} "
        f"score={case.severity_score} level={case.severity_level}"
    )
    return case
