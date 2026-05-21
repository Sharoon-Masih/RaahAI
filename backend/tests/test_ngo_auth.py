# backend/tests/test_ngo_auth.py
# ============================================================
# NGO Auth and Linkage Integration Test
# Command to run: py -m backend.tests.test_ngo_auth
# ============================================================

import logging
import sys
import uuid

from fastapi.testclient import TestClient

from backend.main import app
from backend.config import settings
from backend.services import firebase_service

# Initialize Firebase explicitly for tests
firebase_service.initialize_firebase()

# Setup simple stdout logger
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout
)
logger = logging.getLogger("test_ngo_auth")

def run_tests():
    logger.info("Starting NGO Auth & Linkage Integration Test...")
    
    unique_suffix = str(uuid.uuid4())[:8]
    test_email = f"test_ngo_{unique_suffix}@example.com"
    test_password = "SecurePassword123!"
    
    with TestClient(app) as client:
        # 1. Register NGO
        logger.info(f"\n[Test 1] Registering NGO with email: {test_email}")
        reg_payload = {
            "name": f"Test NGO {unique_suffix}",
            "email": test_email,
            "password": test_password,
            "crisis_types": ["food", "medical"],
            "locations": ["Lahore", "Karachi"]
        }
        res_reg = client.post(f"{settings.API_PREFIX}/ngos/register", json=reg_payload)
        
        if res_reg.status_code != 201:
            logger.error(f"Test 1 FAILED: Registration returned {res_reg.status_code}: {res_reg.text}")
            return
            
        ngo_data = res_reg.json()
        ngo_id = ngo_data["ngo_id"]
        logger.info(f"Test 1 SUCCESS: NGO registered with ID {ngo_id}")
        
        # 2. Login NGO
        logger.info("\n[Test 2] Logging in with correct credentials...")
        login_payload = {
            "email": test_email,
            "password": test_password
        }
        res_login = client.post(f"{settings.API_PREFIX}/ngos/login", json=login_payload)
        
        if res_login.status_code != 200:
            logger.error(f"Test 2 FAILED: Login returned {res_login.status_code}: {res_login.text}")
            return
            
        login_data = res_login.json()
        if login_data.get("ngo_id") != ngo_id:
            logger.error(f"Test 2 FAILED: Expected NGO ID {ngo_id}, got {login_data.get('ngo_id')}")
            return
            
        logger.info("Test 2 SUCCESS: NGO authenticated successfully.")
        
        # 3. Submit Raw Case with NGO Linkage
        logger.info(f"\n[Test 3] Submitting case linked to NGO ID: {ngo_id}")
        case_payload = {
            "raw_input": "Mujhe emergency khana chahiye mera ghar Lahore Gulberg mein hai aur 5 bachay hain bhookay hain. Please help urgently.",
            "submission_source": "web_form",
            "assigned_ngo_id": ngo_id
        }
        # Note: This will run the entire 5-agent pipeline which takes about 10-20 seconds.
        res_case = client.post(f"{settings.API_PREFIX}/submit/raw", json=case_payload)
        
        if res_case.status_code != 200:
            logger.error(f"Test 3 FAILED: Case submission returned {res_case.status_code}: {res_case.text}")
            return
            
        case_data = res_case.json()
        case_obj = case_data.get("case", {})
        linked_ngo_id = case_obj.get("assigned_ngo_id")
        
        if linked_ngo_id != ngo_id:
            logger.error(f"Test 3 FAILED: Case was not properly linked to NGO ID. Found: {linked_ngo_id}")
            return
            
        case_id = case_data.get("case_id")
        logger.info(f"Test 3 SUCCESS: Case {case_id} submitted and successfully linked to NGO {linked_ngo_id} in Firestore.")

    logger.info("\n=== ALL NGO AUTH & LINKAGE TESTS COMPLETED SUCCESSFULLY! ===")

if __name__ == "__main__":
    run_tests()
