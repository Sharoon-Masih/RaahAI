# backend/tests/test_sheets_service.py
# ============================================================
# Google Sheets Service Unit Test
# Command to run: py -m backend.tests.test_sheets_service
# ============================================================

import asyncio
import logging
import sys
import uuid

from backend.config import settings
from backend.services import sheets_service

# Setup simple stdout logger
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout
)
logger = logging.getLogger("test_sheets_service")


async def main():
    logger.info("Starting Google Sheets Service Integration Test...")
    logger.info(f"Target GOOGLE_SHEETS_ID: {settings.GOOGLE_SHEETS_ID}")

    if not settings.GOOGLE_SHEETS_ID:
        logger.error("Error: GOOGLE_SHEETS_ID is not configured in environment variables or .env!")
        return

    # Generate a unique Case ID for this test session
    case_id = f"TEST-{str(uuid.uuid4())[:8].upper()}"
    ticket_id = f"TKT-TEST-{str(uuid.uuid4())[:6].upper()}"

    # ── Test 1: Append Case Row ──────────────────────────────────────
    logger.info(f"\n[Test 1] Testing row APPEND with case ID: {case_id}...")
    try:
        await sheets_service.update_or_append_case(
            case_id=case_id,
            status="PENDING",
            severity_score=4.5,
            severity_level="MEDIUM",
            time_sensitivity="THIS_WEEK",
            volunteer_assigned="Test Volunteer A",
            ticket_id=ticket_id,
        )
        logger.info("Test 1 SUCCESS: Append completed.")
    except Exception as exc:
        logger.error(f"Test 1 FAILED: {exc}", exc_info=True)
        return

    # ── Test 2: Update Case Row ──────────────────────────────────────
    logger.info(f"\n[Test 2] Testing row UPDATE (upsert logic) for case ID: {case_id}...")
    try:
        await sheets_service.update_or_append_case(
            case_id=case_id,
            status="DISPATCHED",
            severity_score=9.0,
            severity_level="CRITICAL",
            time_sensitivity="IMMEDIATE",
            volunteer_assigned="Test Volunteer B (Promoted)",
            ticket_id=ticket_id,
        )
        logger.info("Test 2 SUCCESS: Upsert update completed.")
    except Exception as exc:
        logger.error(f"Test 2 FAILED: {exc}", exc_info=True)
        return

    logger.info("\n=== ALL GOOGLE SHEETS INTEGRATION TESTS COMPLETED SUCCESSFULLY! ===")


if __name__ == "__main__":
    asyncio.run(main())
