import os
import sys
import json
import time
import requests
from dotenv import load_dotenv

# Load .env variables
load_dotenv()

# Setup Python path to import backend services
sys.path.append(os.path.abspath(os.path.dirname(__file__)))
from backend.services import firebase_service

# Define API URL
BASE_URL = "http://127.0.0.1:8000/api/v1"

# Step 1: NGO Registration / Login
def onboard_ngo():
    register_url = f"{BASE_URL}/ngos/register"
    login_url = f"{BASE_URL}/ngos/login"
    
    payload = {
        "name": "Saylani Welfare International Trust",
        "email": "ops@saylani-demo.org",
        "password": "RaahAI@2025",
        "crisis_types": ["food", "medical", "emergency_cash", "flood_relief", "education"],
        "locations": ["Karachi", "Lahore", "Islamabad", "Hyderabad", "Quetta"]
    }
    
    print("Step 1: Attempting to register NGO...")
    try:
        res = requests.post(register_url, json=payload)
        if res.status_code == 201:
            data = res.json()
            print(f"NGO registered successfully. ID: {data['ngo_id']}")
            return data["ngo_id"]
        elif res.status_code == 400:
            print("NGO already registered. Attempting login...")
            res_login = requests.post(login_url, json={
                "email": payload["email"],
                "password": payload["password"]
            })
            if res_login.status_code == 200:
                data = res_login.json()
                print(f"NGO logged in successfully. ID: {data['ngo_id']}")
                return data["ngo_id"]
            else:
                print(f"Login failed: {res_login.status_code} - {res_login.text}")
                sys.exit(1)
        else:
            print(f"Registration failed: {res.status_code} - {res.text}")
            sys.exit(1)
    except Exception as e:
        print(f"Error onboarding NGO: {e}")
        sys.exit(1)

# Step 2: Seed Volunteers in Firebase Firestore
def seed_volunteers():
    print("\nStep 2: Seeding volunteers into Firestore...")
    firebase_service.initialize_firebase()
    db = firebase_service.get_db()
    
    volunteers = [
        {"id": "V-001", "name": "Ahmed Raza", "phone": "+923001112233", "area": "Korangi Karachi", "is_available": True, "lat": 24.8326, "lng": 67.1287},
        {"id": "V-002", "name": "Sara Malik", "phone": "+923111223344", "area": "Gulshan Karachi", "is_available": True, "lat": 24.9215, "lng": 67.0977},
        {"id": "V-003", "name": "Bilal Khan", "phone": "+923331234567", "area": "Lahore Cantt", "is_available": True, "lat": 31.5204, "lng": 74.3587},
        {"id": "V-004", "name": "Zainab Ali", "phone": "+923214445566", "area": "F-10 Islamabad", "is_available": False, "lat": 33.6844, "lng": 73.0479},
        {"id": "V-005", "name": "Usman Tariq", "phone": "+923456677889", "area": "Hyderabad City", "is_available": True, "lat": 25.3960, "lng": 68.3578},
        {"id": "V-006", "name": "Nadia Hussain", "phone": "+923557788990", "area": "Landhi Karachi", "is_available": True, "lat": 24.8607, "lng": 67.2088}
    ]
    
    for vol in volunteers:
        try:
            db.collection("volunteers").document(vol["id"]).set(vol)
            print(f"Volunteer {vol['id']} ({vol['name']}) seeded successfully.")
        except Exception as e:
            print(f"Failed to seed volunteer {vol['id']}: {e}")
            sys.exit(1)

# Step 3: Submit 15 Raw Cases
def submit_raw_cases(ngo_id):
    print("\nStep 3: Submitting 15 raw cases sequentially...")
    cases = [
        {"raw_input": "Mera naam Rehana Bibi hai. Korangi Karachi mein rehti hoon. Shohar 2 hafte se hospital mein hain, 4 bachay hain, koi income nahi. Ration khatam ho gaya. Mujhe madad chahiye.", "submission_source": "google_form"},
        {"raw_input": "My name is Tariq Mahmood. I live in Gulshan-e-Iqbal Karachi. Lost my job 3 months ago. Family of 5. Cannot afford food or school fees. Monthly income zero.", "submission_source": "email"},
        {"raw_input": "Assalam o Alaikum. Main Nasreen hoon Landhi se. Mere bachay 3 din se bhukhay hain. Ghar mein khaana bilkul nahi. Shohar accident mein zakhmi hain. Fauran madad chahiye.", "submission_source": "google_form"},
        {"raw_input": "This is Asif from Islamabad F-8. Single father, 2 kids. Lost wife last year. Income is Rs 8000 per month but rent is Rs 12000. Need emergency cash support.", "submission_source": "email"},
        {"raw_input": "Main Fatima hoon Lahore Cantt say. Meri beti ka operation kal hai. Rs 45000 chahiye. Koi nahi hai jo help kare. Please koi madad karo.", "submission_source": "google_form"},
        {"raw_input": "Name: Imran Sheikh. Location: Hyderabad. Flood damaged our home completely. Family of 8 living on street. Need shelter, food, and clothing urgently.", "submission_source": "google_form"},
        {"raw_input": "Salaam. Mera naam Salma hai, North Karachi. Mere teen bachay school nahi ja rahe kyunki fees nahi de sakti. Husband chhod ke chale gaye. Income bilkul nahi.", "submission_source": "email"},
        {"raw_input": "Hi my name is Kamran. I am from Quetta. My mother needs dialysis 3 times a week. We cannot afford it anymore. Please help us with medical expenses.", "submission_source": "google_form"},
        {"raw_input": "Main Abdul Rehman hoon Orangi Town Karachi se. Ration khatam hua 5 din pehlay. 6 log hain ghar mein. Job nahi mil rahi. Koi bhi zaroorat ki cheez nahi.", "submission_source": "google_form"},
        {"raw_input": "Name: Hina Baig. From Lahore Model Town. My son has dengue fever. Need medicines and hospital support. Monthly income Rs 15000, medical bills Rs 40000.", "submission_source": "email"},
        {"raw_input": "Mera naam Sajid Ali hai. Faisalabad se hoon. Kapra mill band ho gayi. 200 log berozgaar hain. Mere apne 7 bachay hain. Koi income source nahi raha.", "submission_source": "google_form"},
        {"raw_input": "This is Maria from DHA Karachi. My elderly parents need regular medicines for diabetes and blood pressure. We are managing but need monthly medicine support.", "submission_source": "email"},
        {"raw_input": "Aoa. Main Rubina hoon Korangi Industrial Area se. Ghar mein aag lag gayi. Sab kuch khaak ho gaya. 5 bachay hain. Kapray aur khaana dono chahiye.", "submission_source": "google_form"},
        {"raw_input": "Name is Zubair Ahmed from Karachi Malir. My daughter got admission in medical college but cannot afford the fee of Rs 80000. Please help for education.", "submission_source": "email"},
        {"raw_input": "test", "submission_source": "google_form"}
    ]
    
    url = f"{BASE_URL}/submit/raw"
    headers = {
        "Authorization": f"Bearer {ngo_id}",
        "assigned-ngo-id": ngo_id,
        "assigned_ngo_id": ngo_id
    }
    
    for i, case in enumerate(cases, 1):
        print(f"Submitting case {i}/15: {case['raw_input'][:60]}...")
        payload = {
            "raw_input": case["raw_input"],
            "submission_source": case["submission_source"],
            "assigned_ngo_id": ngo_id
        }
        try:
            start_time = time.time()
            res = requests.post(url, json=payload, headers=headers)
            duration = time.time() - start_time
            if res.status_code == 200:
                data = res.json()
                print(f"  Success: Case ID: {data.get('case_id')} | Ticket ID: {data.get('ticket_id')} | Severity: {data.get('severity_level')} | Status: {data.get('dispatch_status')} | Time taken: {duration:.2f}s")
            else:
                print(f"  Failed: Status {res.status_code} - {res.text}")
        except Exception as e:
            print(f"  Error submitting case {i}: {e}")
        # Wait a short bit to ensure sequential logging is neat
        time.sleep(1)

# Step 4: Upload CSV via Spreadsheet Endpoint
def upload_spreadsheet(ngo_id):
    print("\nStep 4: Uploading bulk_cases.csv spreadsheet...")
    url = f"{BASE_URL}/submit/spreadsheet"
    headers = {
        "Authorization": f"Bearer {ngo_id}",
        "assigned-ngo-id": ngo_id,
        "assigned_ngo_id": ngo_id
    }
    
    csv_path = "bulk_cases.csv"
    if not os.path.exists(csv_path):
        print(f"Spreadsheet file {csv_path} not found!")
        sys.exit(1)
        
    try:
        with open(csv_path, "rb") as f:
            files = {"file": (csv_path, f, "text/csv")}
            data = {"assigned_ngo_id": ngo_id}
            
            res = requests.post(url, files=files, data=data, headers=headers, stream=True)
            if res.status_code == 200:
                print("Streaming spreadsheet processing response:")
                for line in res.iter_lines():
                    if line:
                        print("  ", line.decode("utf-8"))
            else:
                print(f"Spreadsheet upload failed: {res.status_code} - {res.text}")
    except Exception as e:
        print(f"Error uploading spreadsheet: {e}")

# Step 5: Verify Dashboard Data and Print Table
def verify_data(ngo_id):
    print("\nStep 5: Verifying dashboard data...")
    headers = {
        "Authorization": f"Bearer {ngo_id}",
        "assigned-ngo-id": ngo_id,
        "assigned_ngo_id": ngo_id
    }
    
    # 1. Summary
    summary = {}
    try:
        res = requests.get(f"{BASE_URL}/dashboard/summary", headers=headers)
        if res.status_code == 200:
            summary = res.json()
            print("Dashboard Summary response successfully retrieved.")
        else:
            print(f"Dashboard summary failed: {res.status_code} - {res.text}")
    except Exception as e:
        print(f"Error fetching dashboard summary: {e}")
        
    # 2. Applications (list)
    applications = {}
    try:
        res = requests.get(f"{BASE_URL}/applications?limit=20", headers=headers)
        if res.status_code == 200:
            applications = res.json()
            print("Applications List response successfully retrieved.")
        else:
            print(f"Applications list failed: {res.status_code} - {res.text}")
    except Exception as e:
        print(f"Error fetching applications: {e}")
        
    # 3. Firebase Stats
    stats = {}
    try:
        res = requests.get(f"{BASE_URL}/firebase/stats", headers=headers)
        if res.status_code == 200:
            stats = res.json()
            print("Firebase Stats response successfully retrieved.")
        else:
            print(f"Firebase stats failed: {res.status_code} - {res.text}")
    except Exception as e:
        print(f"Error fetching stats: {e}")

    # Process and print summary
    print("\n================ VERIFICATION RESULT ================")
    cases_overview = summary.get("cases_overview", {})
    severity_breakdown = summary.get("severity_breakdown", {})
    
    total_cases = cases_overview.get("total_assigned", 0)
    dispatched = cases_overview.get("dispatched", 0)
    failed = cases_overview.get("rejected", 0) # rejected in summary corresponds to FAILED/INVALID status
    
    critical = severity_breakdown.get("critical", 0)
    high = severity_breakdown.get("high", 0)
    medium = severity_breakdown.get("medium", 0)
    low = severity_breakdown.get("low", 0)
    
    print(f"Total Cases: {total_cases}")
    print(f"CRITICAL: {critical} | HIGH: {high} | MEDIUM: {medium} | LOW: {low}")
    print(f"DISPATCHED: {dispatched} | FAILED: {failed}")
    
    # Save verification details to a JSON file for the final report
    report_data = {
        "total_cases": total_cases,
        "critical": critical,
        "high": high,
        "medium": medium,
        "low": low,
        "dispatched": dispatched,
        "failed": failed,
        "volunteers_seeded": 6,
        "csv_rows_uploaded": 5,
        "raw_summary": summary,
        "raw_stats": stats
    }
    with open("seeding_report.json", "w") as rf:
        json.dump(report_data, rf, indent=2)
    print("Verification report saved to seeding_report.json")

def main():
    ngo_id = onboard_ngo()
    seed_volunteers()
    submit_raw_cases(ngo_id)
    upload_spreadsheet(ngo_id)
    verify_data(ngo_id)

if __name__ == "__main__":
    main()
