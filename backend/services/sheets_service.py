# backend/services/sheets_service.py
# ============================================================
# Google Sheets Service — Dynamic multi-tab upsert and routing.
# Uses Google API client with firebase_cred.json service account.
# Classifies and routes cases to: high_priority | low_priority | rejected.
# Performs cross-sheet row deletions to prevent duplicate entries.
# ============================================================

from __future__ import annotations

import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Any

from google.oauth2 import service_account
import googleapiclient.discovery

from backend.config import settings

logger = logging.getLogger(__name__)

_sheets_client = None

# Tab list configuration
TABS = ["high_priority", "low_priority", "rejected"]

# 22-column schema headers
HEADERS = [
    "Case ID",
    "Applicant Name",
    "Phone",
    "Location",
    "Crisis Type",
    "Family Size",
    "Monthly Income",
    "Description (Original)",
    "Description (English)",
    "Validation Status",
    "Validation Reasons",
    "Fraud Signals",
    "Severity Score",
    "Severity Level",
    "Time Sensitivity",
    "Key Ingest / Insight",
    "Delay Consequence",
    "Action Plan",
    "Resource Request",
    "Ticket ID",
    "Timestamp",
    "Assigned NGO ID"
]


def _resolve_service_account() -> Optional[str]:
    """Find the Firebase service account JSON file (also used for Sheets)."""
    candidates = [
        settings.FIREBASE_SERVICE_ACCOUNT_PATH,
        Path(__file__).parent.parent.parent / "firebase_cred.json",
        Path(__file__).parent.parent.parent / "firebase-adminsdk.json",
        Path(__file__).parent.parent / "firebase-adminsdk.json",
        Path(__file__).parent.parent.parent / ".secrets" / "firebase-adminsdk.json",
    ]
    for p in candidates:
        path = Path(p)
        if path.exists():
            return str(path)
    return None


def get_sheets_client() -> googleapiclient.discovery.Resource:
    """Initialize and return Google Sheets API client (singleton)."""
    global _sheets_client
    if _sheets_client is not None:
        return _sheets_client

    sa_path = _resolve_service_account()
    if not sa_path:
        raise RuntimeError(
            "Service account credential file not found. "
            "Please configure FIREBASE_SERVICE_ACCOUNT_PATH or place firebase_cred.json in root."
        )

    try:
        credentials = service_account.Credentials.from_service_account_file(
            sa_path,
            scopes=["https://www.googleapis.com/auth/spreadsheets"],
        )
        _sheets_client = googleapiclient.discovery.build(
            "sheets",
            "v4",
            credentials=credentials,
            cache_discovery=False,
        )
        logger.info(f"Google Sheets service built successfully using SA: {sa_path}")
        return _sheets_client
    except Exception as exc:
        logger.error(f"Failed to initialize Google Sheets API: {exc}")
        raise


async def update_or_append_case(
    target_sheet: str,  # "high_priority" | "low_priority" | "rejected"
    case_id: str,
    applicant_name: Optional[str],
    phone: Optional[str],
    location: Optional[str],
    crisis_type: Optional[str],
    family_size: int,
    income_monthly: int,
    description_original: str,
    description_en: str,
    validation_status: Optional[str],
    validation_reasons: list[str] | str,
    fraud_signals: list[str] | str,
    severity_score: Optional[float],
    severity_level: Optional[str],
    time_sensitivity: Optional[str],
    key_insight: Optional[str],
    delay_consequence: Optional[str],
    action_plan: Optional[str],
    resource_request: Optional[str],
    ticket_id: Optional[str],
    assigned_ngo_id: Optional[str] = None,
    timestamp: Optional[str] = None,
) -> None:
    """
    Classify and route case details to its respected tab (high_priority, low_priority, or rejected).
    Ensures all sheets exist, writes headers if empty, performs cross-sheet deletion of existing
    rows with the same Case ID, and upserts the row into the target tab.
    """
    if not settings.GOOGLE_SHEETS_ID:
        logger.warning("[SheetsService] GOOGLE_SHEETS_ID environment variable is empty. Skipping write.")
        return

    if target_sheet not in TABS:
        raise ValueError(f"Invalid target_sheet '{target_sheet}'. Allowed: {TABS}")

    if not timestamp:
        timestamp = datetime.now(timezone.utc).isoformat()

    client = get_sheets_client()
    spreadsheet_id = settings.GOOGLE_SHEETS_ID

    # Format list fields as friendly strings
    val_reasons_str = (
        ", ".join(validation_reasons)
        if isinstance(validation_reasons, list)
        else (validation_reasons or "")
    )
    fraud_signals_str = (
        ", ".join(fraud_signals)
        if isinstance(fraud_signals, list)
        else (fraud_signals or "")
    )

    # ── Step 1: Fetch spreadsheet metadata & ensure all TABS exist ──
    try:
        spreadsheet = client.spreadsheets().get(spreadsheetId=spreadsheet_id).execute()
        existing_sheets = spreadsheet.get("sheets", [])
        sheet_metadata_map = {
            s.get("properties", {}).get("title"): s.get("properties", {}).get("sheetId")
            for s in existing_sheets
        }
    except Exception as exc:
        logger.error(f"[SheetsService] Failed to read spreadsheet metadata: {exc}")
        raise

    # Dynamically create any missing tabs
    for tab in TABS:
        if tab not in sheet_metadata_map:
            logger.info(f"[SheetsService] Tab '{tab}' not found. Creating it dynamically...")
            body = {
                "requests": [
                    {
                        "addSheet": {
                            "properties": {
                                "title": tab
                            }
                        }
                    }
                ]
            }
            try:
                creation_res = client.spreadsheets().batchUpdate(
                    spreadsheetId=spreadsheet_id,
                    body=body,
                ).execute()
                # Get the newly created sheet ID
                new_sheet_id = (
                    creation_res.get("replies", [{}])[0]
                    .get("addSheet", {})
                    .get("properties", {})
                    .get("sheetId")
                )
                sheet_metadata_map[tab] = new_sheet_id
                logger.info(f"[SheetsService] Tab '{tab}' created with ID: {new_sheet_id}")
            except Exception as exc:
                logger.error(f"[SheetsService] Failed to create tab '{tab}': {exc}")
                raise

    # ── Step 2: Cross-Sheet Row Deletion (Upsert Isolation) ──
    # Clean up this case_id from the other 2 sheets if it exists there
    for tab in TABS:
        if tab == target_sheet:
            continue

        try:
            col_a_res = client.spreadsheets().values().get(
                spreadsheetId=spreadsheet_id,
                range=f"'{tab}'!A:A",
            ).execute()
            col_a = col_a_res.get("values", [])
        except Exception as exc:
            logger.warning(f"[SheetsService] Could not read Column A of '{tab}': {exc}")
            col_a = []

        existing_idx = -1
        for idx, row in enumerate(col_a):
            if idx == 0:
                continue  # Skip headers
            if row and len(row) > 0 and row[0] == case_id:
                existing_idx = idx
                break

        if existing_idx != -1:
            logger.info(
                f"[SheetsService] Case {case_id} found in other tab '{tab}' at row {existing_idx + 1}. Deleting..."
            )
            sheet_id = sheet_metadata_map[tab]
            delete_body = {
                "requests": [
                    {
                        "deleteDimension": {
                            "range": {
                                "sheetId": sheet_id,
                                "dimension": "ROWS",
                                "startIndex": existing_idx,
                                "endIndex": existing_idx + 1,
                            }
                        }
                    }
                ]
            }
            try:
                client.spreadsheets().batchUpdate(
                    spreadsheetId=spreadsheet_id,
                    body=delete_body,
                ).execute()
                logger.info(f"[SheetsService] Deleted case {case_id} row from other tab '{tab}'.")
            except Exception as exc:
                logger.error(f"[SheetsService] Failed to delete row {existing_idx + 1} from '{tab}': {exc}")
                # Non-fatal: continue even if deletion fails

    # ── Step 3: Ensure headers are written in the target sheet ──
    range_name = f"'{target_sheet}'!A:V"
    try:
        target_res = client.spreadsheets().values().get(
            spreadsheetId=spreadsheet_id,
            range=range_name,
        ).execute()
        target_rows = target_res.get("values", [])
    except Exception as exc:
        logger.error(f"[SheetsService] Failed to read target sheet values: {exc}")
        raise

    if not target_rows:
        try:
            client.spreadsheets().values().update(
                spreadsheetId=spreadsheet_id,
                range=f"'{target_sheet}'!A1:V1",
                valueInputOption="RAW",
                body={"values": [HEADERS]},
            ).execute()
            target_rows = [HEADERS]
            logger.info(f"[SheetsService] Headers written successfully to '{target_sheet}'.")
        except Exception as exc:
            logger.error(f"[SheetsService] Failed to write headers to '{target_sheet}': {exc}")
            raise

    # ── Step 4: Search for Case ID inside target sheet ──
    existing_row_idx = -1
    for idx, row in enumerate(target_rows):
        if idx == 0:
            continue
        if row and len(row) > 0 and row[0] == case_id:
            existing_row_idx = idx + 1
            break

    # Build the 22-column data record (excluding volunteer and dispatch status)
    new_row = [
        case_id,
        applicant_name or "",
        phone or "",
        location or "",
        crisis_type or "",
        family_size,
        income_monthly,
        description_original,
        description_en,
        validation_status or "",
        val_reasons_str,
        fraud_signals_str,
        str(severity_score) if severity_score is not None else "",
        severity_level or "",
        time_sensitivity or "",
        key_insight or "",
        delay_consequence or "",
        action_plan or "",
        resource_request or "",
        ticket_id or "",
        timestamp,
        assigned_ngo_id or "",
    ]

    # Fill up to 22 elements if shorter
    while len(new_row) < 22:
        new_row.append("")

    # ── Step 5: Perform Update or Append inside Target Sheet ──
    if existing_row_idx != -1:
        # Update existing row
        target_range = f"'{target_sheet}'!A{existing_row_idx}:V{existing_row_idx}"
        try:
            client.spreadsheets().values().update(
                spreadsheetId=spreadsheet_id,
                range=target_range,
                valueInputOption="RAW",
                body={"values": [new_row]},
            ).execute()
            logger.info(
                f"[SheetsService] Successfully updated case {case_id} in row {existing_row_idx} of '{target_sheet}'."
            )
        except Exception as exc:
            logger.error(f"[SheetsService] Failed to update row {existing_row_idx} in '{target_sheet}': {exc}")
            raise
    else:
        # Append new row
        try:
            client.spreadsheets().values().append(
                spreadsheetId=spreadsheet_id,
                range=f"'{target_sheet}'!A:V",
                valueInputOption="RAW",
                insertDataOption="INSERT_ROWS",
                body={"values": [new_row]},
            ).execute()
            logger.info(
                f"[SheetsService] Successfully appended case {case_id} as a new row in '{target_sheet}'."
            )
        except Exception as exc:
            logger.error(f"[SheetsService] Failed to append row in '{target_sheet}': {exc}")
            raise
