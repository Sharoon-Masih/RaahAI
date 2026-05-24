#!/usr/bin/env python3
"""
Test script to verify Firebase/Firestore setup and connectivity
"""
import sys
import asyncio
from pathlib import Path

# Fix encoding for Windows
sys.stdout.reconfigure(encoding='utf-8')

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent))

from backend.config import settings
from backend.services import firebase_service

async def test_firebase():
    print("=" * 60)
    print("FIREBASE & FIRESTORE CONNECTIVITY TEST")
    print("=" * 60)

    # Test 1: Credentials file exists
    print("\n[TEST 1] Firebase Credentials File")
    print("-" * 60)
    cred_path = firebase_service._resolve_service_account()
    if cred_path:
        print(f"[OK] Credentials found at: {cred_path}")
    else:
        print("[FAIL] Credentials NOT found")
        return False

    # Test 2: Initialize Firebase
    print("\n[TEST 2] Firebase Initialization")
    print("-" * 60)
    try:
        firebase_service.initialize_firebase()
        print("[OK] Firebase initialized successfully")
    except Exception as e:
        print(f"[FAIL] Firebase initialization failed: {e}")
        return False

    # Test 3: Get Firestore client
    print("\n[TEST 3] Firestore Client")
    print("-" * 60)
    try:
        db = firebase_service.get_db()
        print("[OK] Firestore client connected")
    except Exception as e:
        print(f"[FAIL] Firestore client connection failed: {e}")
        return False

    # Test 4: Check NGOs collection
    print("\n[TEST 4] NGOs Collection")
    print("-" * 60)
    try:
        ngos_stream = firebase_service.get_db().collection(settings.COLLECTION_NGOS).stream()
        ngo_list = [doc.to_dict() for doc in ngos_stream]
        print(f"[OK] NGOs collection accessible")
        print(f"   Total NGOs: {len(ngo_list)}")
        if ngo_list:
            print(f"   NGOs in database:")
            for ngo in ngo_list:
                print(f"     - {ngo.get('name')} ({ngo.get('email')})")
        else:
            print(f"   [WARN] No NGOs found in database")
    except Exception as e:
        print(f"[FAIL] Failed to access NGOs collection: {e}")
        return False

    # Test 5: Check other collections
    print("\n[TEST 5] Other Collections")
    print("-" * 60)
    collections = [
        settings.COLLECTION_CASES,
        settings.COLLECTION_TRACES,
        settings.COLLECTION_VOLUNTEERS,
    ]
    for col_name in collections:
        try:
            count = len(list(firebase_service.get_db().collection(col_name).limit(1).stream()))
            print(f"[OK] '{col_name}' collection accessible")
        except Exception as e:
            print(f"[WARN] '{col_name}' collection error: {e}")

    # Test 6: Test password hashing
    print("\n[TEST 6] Password Hashing")
    print("-" * 60)
    try:
        test_password = "test123"
        hashed = firebase_service.hash_password(test_password)
        verified = firebase_service.verify_password(test_password, hashed)
        if verified:
            print(f"[OK] Password hashing working correctly")
        else:
            print(f"[FAIL] Password verification failed")
            return False
    except Exception as e:
        print(f"[FAIL] Password hashing error: {e}")
        return False

    print("\n" + "=" * 60)
    print("[SUCCESS] ALL TESTS PASSED")
    print("=" * 60)
    print("\nNEXT STEPS:")
    print("1. If NGOs are empty, register a new NGO first")
    print("2. Then try to login with those credentials")
    print("3. Check the backend logs for detailed error messages")
    return True

if __name__ == "__main__":
    result = asyncio.run(test_firebase())
    sys.exit(0 if result else 1)
