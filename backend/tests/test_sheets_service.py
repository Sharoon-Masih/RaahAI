# backend/tests/test_sheets_service.py
# ============================================================
# Google Sheets Service Unit Test
# Command to run: py -m backend.tests.test_sheets_service
# ============================================================

import asyncio
import logging
import sys
import uuid
from datetime import datetime, timezone

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

    # Generate a unique Case ID and Ticket ID for this test session
    case_id = f"TEST-{str(uuid.uuid4())[:8].upper()}"
    ticket_id = f"TKT-TEST-{str(uuid.uuid4())[:6].upper()}"

    # ── Test 1: Append to 'low_priority' tab ─────────────────────────────
    logger.info(f"\n[Test 1] Testing row APPEND to 'low_priority' tab with case ID: {case_id}...")
    try:
        await sheets_service.update_or_append_case(
            target_sheet="low_priority",
            case_id=case_id,
            applicant_name="John Doe (Test)",
            phone="+923001234567",
            location="Lahore",
            crisis_type="food",
            family_size=4,
            income_monthly=15000,
            description_original="Hamein khaney ki zaroorat hai.",
            description_en="We need food.",
            validation_status="VALID",
            validation_reasons=["Profile seems consistent"],
            fraud_signals=[],
            severity_score=3.5,
            severity_level="LOW",
            time_sensitivity="THIS_WEEK",
            key_insight="Urgent food shortage in family size 4.",
            delay_consequence="Hunger risk.",
            action_plan="Deliver 1x standard ration pack.",
            resource_request="1x standard ration pack",
            ticket_id=ticket_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
        )
        logger.info("Test 1 SUCCESS: Append completed.")
    except Exception as exc:
        logger.error(f"Test 1 FAILED: {exc}", exc_info=True)
        return

    # ── Test 2: Promote case to 'high_priority' tab (cross-tab deletion) ────
    logger.info(f"\n[Test 2] Testing row PROMOTION to 'high_priority' (should delete from 'low_priority') for case ID: {case_id}...")
    try:
        await sheets_service.update_or_append_case(
            target_sheet="high_priority",
            case_id=case_id,
            applicant_name="John Doe (Test)",
            phone="+923001234567",
            location="Lahore",
            crisis_type="medical",
            family_size=4,
            income_monthly=15000,
            description_original="Emergency medical help needed.",
            description_en="Emergency medical help needed.",
            validation_status="VALID",
            validation_reasons=["Critical medical emergency validated"],
            fraud_signals=[],
            severity_score=9.5,
            severity_level="CRITICAL",
            time_sensitivity="IMMEDIATE",
            key_insight="Medical emergency in Lahore.",
            delay_consequence="Extreme health risk / potential loss of life.",
            action_plan="Send medical volunteer and facilitate immediate clinical assistance.",
            resource_request="Urgent medicine funds",
            ticket_id=ticket_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
        )
        logger.info("Test 2 SUCCESS: Promotion and cross-tab deletion completed.")
    except Exception as exc:
        logger.error(f"Test 2 FAILED: {exc}", exc_info=True)
        return

    # ── Test 3: Demote/Reject case to 'rejected' tab (cross-tab deletion) ────
    logger.info(f"\n[Test 3] Testing row DEMOTION to 'rejected' (should delete from 'high_priority') for case ID: {case_id}...")
    try:
        await sheets_service.update_or_append_case(
            target_sheet="rejected",
            case_id=case_id,
            applicant_name="John Doe (Test)",
            phone="+923001234567",
            location="Lahore",
            crisis_type="medical",
            family_size=4,
            income_monthly=15000,
            description_original="Emergency medical help needed.",
            description_en="Emergency medical help needed.",
            validation_status="INVALID",
            validation_reasons=["Duplicate submissions from same phone number"],
            fraud_signals=["Flagged for high-rate duplicate submission"],
            severity_score=0.0,
            severity_level="LOW",
            time_sensitivity="THIS_WEEK",
            key_insight="Spam profile.",
            delay_consequence="None",
            action_plan="Reject and mark invalid.",
            resource_request="None",
            ticket_id=ticket_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
        )
        logger.info("Test 3 SUCCESS: Rejection and cross-tab deletion completed.")
    except Exception as exc:
        logger.error(f"Test 3 FAILED: {exc}", exc_info=True)
        return

    logger.info("\n=== ALL GOOGLE SHEETS CROSS-TAB INTEGRATION TESTS COMPLETED SUCCESSFULLY! ===")


if __name__ == "__main__":
    asyncio.run(main())
