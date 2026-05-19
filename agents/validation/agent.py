# agents/validation/agent.py
# ============================================================
# Validation Agent — Stage 2 of 5
# Receives CaseObject from Intake, determines authenticity.
#
# CONTRACT:
#   INPUT:  CaseObject (pipeline_stage == "INTAKE_COMPLETE")
#   OUTPUT: CaseObject with validation_status set
#
# NEVER modifies severity, impact, or dispatch fields.
# NEVER drops a case — defaults to NEED_MORE_INFO on error.
# ============================================================

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone

from shared.schemas import (
    CaseObject,
    DispatchStatus,
    TraceObject,
    ValidationStatus,
)

logger = logging.getLogger(__name__)


async def run(case: CaseObject) -> CaseObject:
    """
    Run Validation Agent on a CaseObject from Intake Agent.
    Returns the same CaseObject with validation fields populated.
    """
    from backend.services.gemini_service import run_agent_prompt
    from agents.validation.prompt import VALIDATION_AGENT_SYSTEM_PROMPT

    logger.info(f"[ValidationAgent] Processing case {case.case_id}...")

    # ── Pass-through: already failed cases ───────────────────
    if case.dispatch_status == DispatchStatus.FAILED or case.pipeline_stage == "INTAKE_FAILED":
        case.append_trace(TraceObject(
            agent="ValidationAgent",
            timestamp=datetime.now(timezone.utc).isoformat(),
            action="PASS_THROUGH",
            reasoning="Case arrived with FAILED status from Intake Agent. Skipping validation.",
            tool_calls=[],
            output_summary="Pass-through. dispatch_status remains FAILED.",
        ))
        case.pipeline_stage = "validation_agent"
        return case

    # ── Build user message with case data ───────────────────
    user_message = (
        f"Validate this welfare case application:\n\n"
        f"applicant_name: {case.applicant_name}\n"
        f"phone: {case.phone}\n"
        f"location_normalized: {case.location_normalized}\n"
        f"crisis_type: {case.crisis_type}\n"
        f"family_size: {case.family_size}\n"
        f"income_monthly: {case.income_monthly}\n"
        f"has_children: {case.has_children}\n"
        f"medical_emergency: {case.medical_emergency}\n"
        f"language_detected: {case.language_detected}\n"
        f"description_en: {case.description_en}\n"
        f"description_original: {case.description_original}\n"
        f"pipeline_stage: {case.pipeline_stage}\n"
    )

    # ── Call Gemini ──────────────────────────────────────────
    result = await run_agent_prompt(
        system_prompt=VALIDATION_AGENT_SYSTEM_PROMPT,
        user_message=user_message,
        temperature=0.1,
        model_name="gemini-2.5-flash",
    )

    # ── Default on Gemini failure: NEED_MORE_INFO (never block) ──
    if result is None:
        result = {
            "validation_status": "NEED_MORE_INFO",
            "validation_reasons": ["Validation service unavailable — defaulting to NEED_MORE_INFO."],
            "fraud_signals": [],
            "consistency_notes": [],
        }

    # ── Apply results to CaseObject ──────────────────────────
    status_str = result.get("validation_status", "NEED_MORE_INFO")
    try:
        case.validation_status = ValidationStatus(status_str)
    except ValueError:
        case.validation_status = ValidationStatus.NEED_MORE_INFO

    case.validation_reasons = result.get("validation_reasons", [])
    case.fraud_signals = result.get("fraud_signals", [])
    case.pipeline_stage = "validation_agent"

    # Mark INVALID cases as FAILED — they stop here
    if case.validation_status == ValidationStatus.INVALID:
        case.dispatch_status = DispatchStatus.FAILED

    # ── Append trace ─────────────────────────────────────────
    reasoning = (
        f"Reasons: {case.validation_reasons}. "
        f"Fraud signals: {case.fraud_signals}. "
        f"Consistency: {result.get('consistency_notes', [])}."
    )
    case.append_trace(TraceObject(
        agent="ValidationAgent",
        timestamp=datetime.now(timezone.utc).isoformat(),
        action=f"Case validated: {case.validation_status}",
        reasoning=reasoning,
        tool_calls=["gemini_api"],
        output_summary=(
            f"Status: {case.validation_status}. "
            f"Case proceeds: {case.validation_status != ValidationStatus.INVALID}."
        ),
    ))

    logger.info(
        f"[ValidationAgent] Done. case_id={case.case_id} "
        f"validation_status={case.validation_status}"
    )
    return case
