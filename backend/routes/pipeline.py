# backend/routes/pipeline.py
# ============================================================
# /submit-case — End-to-end pipeline endpoint.
# Accepts raw text, runs all 5 agents, returns full CaseObject.
# This is the primary demo endpoint for the hackathon.
# ============================================================

from __future__ import annotations

import logging

from typing import Optional
from fastapi import APIRouter, HTTPException, status, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from backend.services import firebase_service
from backend.services.pipeline import run_pipeline
from shared.schemas import SubmissionSource

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/submit", tags=["Pipeline"])


class SubmitRawRequest(BaseModel):
    raw_input: str
    submission_source: str = "web_form"
    assigned_ngo_id: Optional[str] = None


@router.post(
    "/raw",
    summary="Submit raw text input and run full 5-agent pipeline",
    response_model=dict,
    status_code=status.HTTP_200_OK,
)
async def submit_raw(req: SubmitRawRequest) -> dict:
    """
    Full end-to-end pipeline endpoint.

    1. Intake Agent  → structures raw text into CaseObject
    2. Validation    → authenticates and flags case
    3. Severity & Impact → scores urgency and predicts time sensitivity
    4. Action        → generates execution plan and resource requests
    5. Dispatch      → assigns volunteer, generates ticket + SMS

    Returns the complete processed CaseObject.
    """
    try:
        case = await run_pipeline(
            raw_input=req.raw_input,
            submission_source=req.submission_source,
            assigned_ngo_id=req.assigned_ngo_id,
        )
    except Exception as exc:
        logger.error(f"[Pipeline] Unhandled error: {exc}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Pipeline execution failed: {str(exc)}",
        )

    # Store final state in Firebase
    try:
        await firebase_service.write_case(case.to_firestore_dict())
    except Exception as exc:
        logger.warning(f"[Pipeline] Firebase write failed after pipeline: {exc}")
        # Non-fatal — return result even if storage fails

    return {
        "success": True,
        "case_id": case.case_id,
        "ticket_id": case.ticket_id,
        "dispatch_status": case.dispatch_status.value if case.dispatch_status else None,
        "validation_status": case.validation_status.value if case.validation_status else None,
        "severity_score": case.severity_score,
        "severity_level": case.severity_level.value if case.severity_level else None,
        "time_sensitivity": case.time_sensitivity.value if case.time_sensitivity else None,
        "volunteer_assigned": case.volunteer_assigned,
        "sms_draft": case.sms_draft,
        "pipeline_stage": case.pipeline_stage,
        "trace_count": len(case.agent_trace),
        "case": case.to_firestore_dict(),
    }


@router.post(
    "/spreadsheet",
    summary="Upload a CSV or XLSX spreadsheet and process row by row with progress streaming",
)
async def submit_spreadsheet(
    file: UploadFile = File(...),
    assigned_ngo_id: Optional[str] = Form(None),
):
    """
    Upload a CSV or XLSX spreadsheet. The system processes each application in the sheet
    row by row using the full 5-agent pipeline.
    
    Returns a StreamingResponse of JSON lines indicating the processing progress
    (e.g., percentage complete), so the mobile app can show a loader.
    """
    import io
    import csv
    import json
    from fastapi.responses import StreamingResponse
    
    content = await file.read()
    filename = file.filename.lower() if file.filename else ""
    
    rows = []
    try:
        if filename.endswith(".csv"):
            text = content.decode("utf-8", errors="ignore")
            reader = csv.DictReader(io.StringIO(text))
            for row in reader:
                # Convert row dictionary to a structured text representation
                row_text = "\\n".join([f"{k}: {v}" for k, v in row.items() if v])
                if row_text.strip():
                    rows.append(row_text)
        elif filename.endswith(".xlsx"):
            import openpyxl
            wb = openpyxl.load_workbook(io.BytesIO(content), data_only=True)
            sheet = wb.active
            headers = [str(cell.value) if cell.value else f"Col_{i}" for i, cell in enumerate(sheet[1])]
            for row in sheet.iter_rows(min_row=2, values_only=True):
                row_dict = dict(zip(headers, row))
                row_text = "\\n".join([f"{k}: {v}" for k, v in row_dict.items() if v])
                if row_text.strip():
                    rows.append(row_text)
        else:
            raise HTTPException(status_code=400, detail="Only .csv and .xlsx files are supported.")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to parse spreadsheet: {str(exc)}")

    if not rows:
        raise HTTPException(status_code=400, detail="Spreadsheet is empty or invalid.")

    async def process_spreadsheet_stream():
        total = len(rows)
        for i, row_text in enumerate(rows):
            try:
                case = await run_pipeline(
                    raw_input=row_text,
                    submission_source="spreadsheet",
                    assigned_ngo_id=assigned_ngo_id,
                )
                try:
                    await firebase_service.write_case(case.to_firestore_dict())
                except Exception as db_exc:
                    logger.warning(f"[Pipeline] Firebase write failed for row {i+1}: {db_exc}")
                
                percentage = int(((i + 1) / total) * 100)
                yield json.dumps({
                    "status": "success",
                    "row": i + 1,
                    "total": total,
                    "percentage": percentage,
                    "case_id": case.case_id,
                    "validation_status": case.validation_status.value if case.validation_status else None
                }) + "\n"
            except Exception as e:
                percentage = int(((i + 1) / total) * 100)
                yield json.dumps({
                    "status": "error",
                    "row": i + 1,
                    "total": total,
                    "percentage": percentage,
                    "error": str(e)
                }) + "\n"

    return StreamingResponse(process_spreadsheet_stream(), media_type="application/x-ndjson")
