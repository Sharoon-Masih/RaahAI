import asyncio
import uuid
import random
from datetime import datetime, timedelta, timezone

import firebase_admin
from firebase_admin import credentials, firestore

from backend.config import settings
from backend.services.firebase_service import initialize_firebase, get_db, write_ngo, hash_password
from shared.schemas import CaseObject, TraceObject, CrisisType, SeverityLevel, DispatchStatus, TimeSensitivity

# Mock data sources
NAMES = [
    "Fatima Bibi", "Ahmed Khan", "Zainab Noor", "Mohammad Ali", "Rukhsana Bano",
    "Usman Tariq", "Sara Khalid", "Bilal Raza", "Hina Javed", "Kamran Syed",
    "Ayesha Malik", "Omar Farooq", "Sana Iftikhar", "Hassan Nawaz", "Sadia Rehman",
    "Tariq Jameel", "Nadia Hussain", "Fahad Mustafa", "Khadija Shah", "Imran Abbas",
    "Nida Yasir", "Atif Aslam", "Mahira Khan", "Fawad Khan", "Sajal Aly"
]

LOCATIONS = [
    "Korangi, Karachi", "DHA, Lahore", "F-8, Islamabad", "Gulshan, Karachi", "Model Town, Lahore",
    "Johar Town, Lahore", "Clifton, Karachi", "Saddar, Rawalpindi", "G-11, Islamabad", "Bahria Town, Rawalpindi",
    "Satellite Town, Quetta", "Latifabad, Rawalpindi", "Cantt, Peshawar", "Gulberg, Lahore", "Defense View, Karachi"
]

CRISIS_TYPES = [CrisisType.FOOD, CrisisType.MEDICAL, CrisisType.EDUCATION, CrisisType.EMERGENCY_CASH, CrisisType.FLOOD_RELIEF]
SEVERITIES = [SeverityLevel.LOW, SeverityLevel.MEDIUM, SeverityLevel.HIGH, SeverityLevel.CRITICAL]
STATUSES = [DispatchStatus.PENDING, DispatchStatus.PROCESSING, DispatchStatus.DISPATCHED, DispatchStatus.FAILED]

async def seed_data():
    print("Initializing Firebase...")
    initialize_firebase()
    db = get_db()
    
    ngo_id = str(uuid.uuid4())
    print(f"Creating NGO with ID: {ngo_id}")
    
    # 1. Create NGO
    ngo_data = {
        "ngo_id": ngo_id,
        "name": "Saylani Welfare Trust (Seed)",
        "email": "admin@saylani.org",
        "password_hash": hash_password("password123"), # So we can login
        "crisis_types": ["food", "medical", "education", "emergency_cash", "flood_relief"],
        "locations": ["Karachi", "Lahore", "Islamabad"],
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await write_ngo(ngo_id, ngo_data)
    
    # 2. Create 25 Volunteers
    print("Creating Volunteers...")
    batch = db.batch()
    volunteers_col = db.collection(settings.COLLECTION_VOLUNTEERS)
    
    for i in range(25):
        vol_id = str(uuid.uuid4())
        vol_ref = volunteers_col.document(vol_id)
        batch.set(vol_ref, {
            "volunteer_id": vol_id,
            "name": f"Volunteer {NAMES[i]}",
            "location": random.choice(LOCATIONS),
            "is_available": random.choice([True, True, True, False]), # Mostly available
            "assigned_ngo_id": ngo_id,
            "skills": [random.choice(["Medical", "Logistics", "Distribution", "Teaching"])],
            "rating": round(random.uniform(3.5, 5.0), 1)
        })
    batch.commit()
    print("25 Volunteers created.")
    
    # 3. Create 30 Cases
    print("Creating Cases...")
    cases_col = db.collection(settings.COLLECTION_CASES)
    now = datetime.now(timezone.utc)
    
    for i in range(30):
        # Generate a random timestamp within the last 14 days
        days_ago = random.randint(0, 13)
        hours_ago = random.randint(0, 23)
        case_time = now - timedelta(days=days_ago, hours=hours_ago)
        
        status = random.choice(STATUSES)
        
        c = CaseObject(
            applicant_name=random.choice(NAMES),
            phone=f"0300{random.randint(1000000, 9999999)}",
            location_normalized=random.choice(LOCATIONS),
            crisis_type=random.choice(CRISIS_TYPES),
            family_size=random.randint(1, 8),
            income_monthly=random.choice([0, 5000, 10000, 15000]),
            description_original="Bohot zarurat hai madad ki.",
            description_en="Need help urgently.",
            severity_level=random.choice(SEVERITIES),
            severity_score=round(random.uniform(2.0, 9.5), 1),
            time_sensitivity=random.choice(list(TimeSensitivity)),
            dispatch_status=status,
            assigned_ngo_id=ngo_id,
            pipeline_stage="completed"
        )
        
        # Add initial trace for creation time
        c.append_trace(TraceObject(
            agent="Intake Agent",
            timestamp=case_time.isoformat(),
            action="Parsed input",
            reasoning="Received from form",
            output_summary="Parsed"
        ))
        
        # If dispatched, add a recent trace to simulate resolution time
        if status == DispatchStatus.DISPATCHED:
            resolve_time = case_time + timedelta(hours=random.randint(1, 48))
            # clamp resolve time to not be in the future
            if resolve_time > now:
                resolve_time = now
            c.append_trace(TraceObject(
                agent="Dispatch Agent",
                timestamp=resolve_time.isoformat(),
                action="Dispatched volunteer",
                reasoning="Found match",
                output_summary="Dispatched"
            ))
            
        cases_col.document(c.case_id).set(c.to_firestore_dict())
        
    print("30 Cases created.")
    print("Seed complete! Use admin@saylani.org / password123 to login.")
    
if __name__ == "__main__":
    asyncio.run(seed_data())
