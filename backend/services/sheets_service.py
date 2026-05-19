# backend/services/sheets_service.py
# ============================================================
# Google Sheets Service — Dynamic row append and update logic.
# Uses Google API client with firebase_cred.json service account.
# Writes/Updates cases inside the sheet tab named "results".
# ============================================================

from __future__ import annotations

import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from google.oauth2 import service_account
import googleapiclient.discovery

from backend.config import settings

logger = logging.getLogger(__name__)

_sheets_client = None


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
    case_id: str,
    status: str,
    severity_score: Optional[float],
    severity_level: Optional[str],
    time_sensitivity: Optional[str],
    volunteer_assigned: Optional[str],
    ticket_id: Optional[str],
    timestamp: Optional[str] = None,
) -> None:
    """
    Ensure the "results" tab exists inside the target Google Sheet,
    and then write or update the case details in it.
    If the case already exists in column A, the row is updated.
    Otherwise, the case is appended as a new row.
    """
    if not settings.GOOGLE_SHEETS_ID:
        logger.warning("[SheetsService] GOOGLE_SHEETS_ID environment variable is empty. Skipping write.")
        return

    if not timestamp:
        timestamp = datetime.now(timezone.utc).isoformat()

    client = get_sheets_client()
    spreadsheet_id = settings.GOOGLE_SHEETS_ID
    sheet_name = "results"

    # ── Step 1: Ensure the "results" tab exists in the Sheet ──
    try:
        spreadsheet = client.spreadsheets().get(spreadsheetId=spreadsheet_id).execute()
        sheets = spreadsheet.get("sheets", [])
        results_tab_exists = any(
            s.get("properties", {}).get("title") == sheet_name for s in sheets
        )
    except Exception as exc:
        logger.error(f"[SheetsService] Failed to read spreadsheet metadata: {exc}")
        raise

    if not results_tab_exists:
        logger.info(f"[SheetsService] Tab '{sheet_name}' not found. Creating it dynamically...")
        body = {
            "requests": [
                {
                    "addSheet": {
                        "properties": {
                            "title": sheet_name
                        }
                    }
                }
            ]
        }
        try:
            client.spreadsheets().batchUpdate(
                spreadsheetId=spreadsheet_id,
                body=body,
            ).execute()
            logger.info(f"[SheetsService] Tab '{sheet_name}' created successfully.")
        except Exception as exc:
            logger.error(f"[SheetsService] Failed to create tab '{sheet_name}': {exc}")
            raise

    # ── Step 2: Retrieve current row values to search for case_id ──
    range_name = f"'{sheet_name}'!A:H"
    try:
        result = client.spreadsheets().values().get(
            spreadsheetId=spreadsheet_id,
            range=range_name,
        ).execute()
        rows = result.get("values", [])
    except Exception as exc:
        logger.error(f"[SheetsService] Failed to fetch spreadsheet values: {exc}")
        raise

    headers = [
        "Case ID",
        "Status",
        "Severity Score",
        "Severity Level",
        "Time Sensitivity",
        "Volunteer Assigned",
        "Ticket ID",
        "Timestamp",
    ]

    # Write headers if sheet is empty
    if not rows:
        try:
            client.spreadsheets().values().update(
                spreadsheetId=spreadsheet_id,
                range=f"'{sheet_name}'!A1:H1",
                valueInputOption="RAW",
                body={"values": [headers]},
            ).execute()
            rows = [headers]
            logger.info(f"[SheetsService] Headers written successfully to '{sheet_name}'.")
        except Exception as exc:
            logger.error(f"[SheetsService] Failed to write headers: {exc}")
            raise

    # ── Step 3: Search for Case ID in Column A (skip header row) ──
    existing_row_idx = -1
    for idx, row in enumerate(rows):
        if idx == 0:
            continue  # Skip headers
        if row and len(row) > 0 and row[0] == case_id:
            existing_row_idx = idx + 1  # 1-based sheet row number
            break

    new_row = [
        case_id,
        status,
        str(severity_score) if severity_score is not None else "",
        severity_level or "",
        time_sensitivity or "",
        volunteer_assigned or "",
        ticket_id or "",
        timestamp,
    ]

    # ── Step 4: Perform Update or Append ──
    if existing_row_idx != -1:
        # Update existing row
        target_range = f"'{sheet_name}'!A{existing_row_idx}:H{existing_row_idx}"
        try:
            client.spreadsheets().values().update(
                spreadsheetId=spreadsheet_id,
                range=target_range,
                valueInputOption="RAW",
                body={"values": [new_row]},
            ).execute()
            logger.info(
                f"[SheetsService] Successfully updated case {case_id} in row {existing_row_idx}."
            )
        except Exception as exc:
            logger.error(f"[SheetsService] Failed to update row {existing_row_idx}: {exc}")
            raise
    else:
        # Append new row
        try:
            client.spreadsheets().values().append(
                spreadsheetId=spreadsheet_id,
                range=f"'{sheet_name}'!A:H",
                valueInputOption="RAW",
                insertDataOption="INSERT_ROWS",
                body={"values": [new_row]},
            ).execute()
            logger.info(f"[SheetsService] Successfully appended case {case_id} as a new row.")
        except Exception as exc:
            logger.error(f"[SheetsService] Failed to append row for case {case_id}: {exc}")
            raise
