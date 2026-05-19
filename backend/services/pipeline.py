# backend/services/pipeline.py
# ============================================================
# Pipeline Orchestrator — runs all 5 agents sequentially.
# Called by the /submit-case endpoint.
#
# ORDER (strictly enforced):
#   1. Intake Agent
#   2. Validation Agent
#   3. Severity & Impact Agent
#   4. Action Generation Agent
#   5. Dispatch Agent
#
# RULES:
#   - Sequential only — no parallel mutation
#   - No agent is skipped (failed cases pass through)
#   - Every failure is logged — cases are never dropped
# ============================================================

from __future__ import annotations

import logging
import asyncio
from datetime import datetime, timezone

from shared.schemas import CaseObject, DispatchStatus, TraceObject

logger = logging.getLogger(__name__)


async def run_pipeline(raw_input: str, submission_source: str = "web_form") -> CaseObject:
    """
    Run the full 5-agent pipeline on a raw text input.

    Args:
        raw_input: Unstructured text from any source.
        submission_source: "flutter_app" | "web_form" | "staff_entry"

    Returns:
        Fully processed CaseObject.
    """
    logger.info(f"[Pipeline] Starting. source={submission_source} len={len(raw_input)}")

    # ── Stage 1: Intake Agent ────────────────────────────────
    case = await _run_stage(
        stage_name="IntakeAgent",
        coro=_run_intake(raw_input, submission_source),
    )
    await asyncio.sleep(3)

    # ── Stage 2: Validation Agent ────────────────────────────
    case = await _run_stage(
        stage_name="ValidationAgent",
        coro=_run_validation(case),
        case=case,
    )
    await asyncio.sleep(3)

    # ── Stage 3: Severity & Impact Agent ─────────────────────
    case = await _run_stage(
        stage_name="SeverityImpactAgent",
        coro=_run_severity_impact(case),
        case=case,
    )
    await asyncio.sleep(3)

    # ── Stage 4: Action Generation Agent ─────────────────────
    case = await _run_stage(
        stage_name="ActionAgent",
        coro=_run_action(case),
        case=case,
    )
    await asyncio.sleep(3)

    # ── Stage 5: Dispatch Agent ──────────────────────────────
    case = await _run_stage(
        stage_name="DispatchAgent",
        coro=_run_dispatch(case),
        case=case,
    )

    logger.info(
        f"[Pipeline] Complete. case_id={case.case_id} "
        f"status={case.dispatch_status} ticket={case.ticket_id}"
    )
    return case


# ── Individual agent wrappers ────────────────────────────────

async def _run_intake(raw_input: str, submission_source: str) -> CaseObject:
    from agents.intake.agent import run
    return await run(raw_input, submission_source)


async def _run_validation(case: CaseObject) -> CaseObject:
    from agents.validation.agent import run
    return await run(case)


async def _run_severity_impact(case: CaseObject) -> CaseObject:
    from agents.severity_impact.agent import run
    return await run(case)


async def _run_action(case: CaseObject) -> CaseObject:
    from agents.action.agent import run
    return await run(case)


async def _run_dispatch(case: CaseObject) -> CaseObject:
    from agents.dispatch.agent import run
    return await run(case)


# ── Safe stage runner ────────────────────────────────────────

async def _run_stage(
    stage_name: str,
    coro,
    case: CaseObject | None = None,
) -> CaseObject:
    """
    Safely execute one pipeline stage.
    On exception: marks case as FAILED, appends error trace, continues pipeline.
    NEVER raises — never drops a case.
    """
    import asyncio

    try:
        result = await coro
        logger.debug(f"[Pipeline] {stage_name} completed. stage={result.pipeline_stage}")
        return result

    except Exception as exc:
        logger.error(f"[Pipeline] {stage_name} EXCEPTION: {exc}", exc_info=True)

        # If we have a case object, mark it as failed and return it
        if case is not None:
            case.dispatch_status = DispatchStatus.FAILED
            case.pipeline_stage = f"{stage_name.lower()}_error"
            case.append_trace(TraceObject(
                agent=stage_name,
                timestamp=datetime.now(timezone.utc).isoformat(),
                action="STAGE_ERROR",
                reasoning=f"Unhandled exception in {stage_name}: {str(exc)}",
                tool_calls=[],
                output_summary=f"ERROR in {stage_name}. Pipeline continues with FAILED status.",
            ))
            return case

        # If intake itself failed before producing any case object
        import uuid
        emergency_case = CaseObject(
            case_id=str(uuid.uuid4()),
            dispatch_status=DispatchStatus.FAILED,
            pipeline_stage="pipeline_error",
        )
        emergency_case.append_trace(TraceObject(
            agent=stage_name,
            timestamp=datetime.now(timezone.utc).isoformat(),
            action="PIPELINE_ERROR",
            reasoning=f"Fatal error before CaseObject was created: {str(exc)}",
            tool_calls=[],
            output_summary="Emergency CaseObject created. Pipeline failed.",
        ))
        return emergency_case
