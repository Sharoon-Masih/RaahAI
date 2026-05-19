# agents/action/agent.py
# ============================================================
# Action Agent — Stage 4 of 5
# Generates action plans and resource requests.
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

async def run(case: CaseObject) -> CaseObject:
    """Run Action Agent on a CaseObject."""
    from backend.services.gemini_service import run_agent_prompt
    from agents.action.prompt import ACTION_AGENT_SYSTEM_PROMPT

    logger.info(f"[ActionAgent] Processing case {case.case_id}...")

    if (
        case.dispatch_status == DispatchStatus.FAILED
        or case.validation_status == ValidationStatus.INVALID
    ):
        case.pipeline_stage = "action_agent"
        case.append_trace(TraceObject(
            agent="ActionAgent",
            timestamp=datetime.now(timezone.utc).isoformat(),
            action="SKIPPED",
            reasoning="Case is INVALID or FAILED.",
            tool_calls=[],
            output_summary="Skipped action generation.",
        ))
        return case

    user_message = (
        f"Generate action plan for:\n\n"
        f"Crisis Type: {case.crisis_type}\n"
        f"Family Size: {case.family_size}\n"
        f"Severity Level: {case.severity_level}\n"
        f"Time Sensitivity: {case.time_sensitivity}\n"
        f"Medical Emergency: {case.medical_emergency}\n"
        f"Description: {case.description_en}\n"
    )

    result = await run_agent_prompt(
        system_prompt=ACTION_AGENT_SYSTEM_PROMPT,
        user_message=user_message,
        temperature=0.3,
        model_name="gemini-2.5-flash",
    )

    if result is None:
        result = {
            "action_plan": "1. Contact family to assess immediate needs.\n2. Dispatch closest volunteer.",
            "resource_request": "Standard emergency kit based on crisis type.",
            "volunteer_profile_request": "Any available volunteer in the area."
        }

    case.action_plan = result.get("action_plan")
    case.resource_request = result.get("resource_request")
    case.volunteer_profile_request = result.get("volunteer_profile_request")
    case.pipeline_stage = "action_agent"

    case.append_trace(TraceObject(
        agent="ActionAgent",
        timestamp=datetime.now(timezone.utc).isoformat(),
        action="Generated Action Plan",
        reasoning="Based on severity and crisis type.",
        tool_calls=["gemini_api"],
        output_summary="Action plan and resource request generated.",
    ))

    logger.info(f"[ActionAgent] Done. case_id={case.case_id}")
    return case
