# backend/routes/ngos.py
# ============================================================
# /ngos — NGO registration and login authentication endpoints.
# Firestore-backed database storage with custom PBKDF2 hashing.
# ============================================================

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status

from backend.services import firebase_service
from shared.schemas import NGOLoginRequest, NGORegisterRequest, NGOResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ngos", tags=["NGO Authentication"])


@router.post(
    "/register",
    summary="Register a new NGO",
    response_model=NGOResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_ngo(req: NGORegisterRequest) -> NGOResponse:
    """
    Onboard a new humanitarian NGO partner:
    1. Generates a unique UUID as ngo_id.
    2. Hashes the password using secure standard hashlib pbkdf2.
    3. Saves the profile to Firestore collection 'ngos'.
    """
    email_clean = req.email.strip().lower()

    # Check for existing email to prevent duplicates
    existing = await firebase_service.get_ngo_by_email(email_clean)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"An NGO partner with email '{req.email}' is already registered.",
        )

    ngo_id = str(uuid.uuid4())
    password_hash = firebase_service.hash_password(req.password)
    created_at_iso = datetime.now(timezone.utc).isoformat()

    ngo_data = {
        "ngo_id": ngo_id,
        "name": req.name.strip(),
        "email": email_clean,
        "password_hash": password_hash,
        "crisis_types": [c.strip() for c in req.crisis_types],
        "locations": [l.strip() for l in req.locations],
        "created_at": created_at_iso,
    }

    try:
        await firebase_service.write_ngo(ngo_id, ngo_data)
        logger.info(f"[NGO Router] Registered NGO '{req.name}' successfully with ID: {ngo_id}")
    except Exception as exc:
        logger.error(f"[NGO Router] Registration failed for NGO '{req.name}': {exc}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save NGO credentials: {str(exc)}",
        )

    return NGOResponse(
        ngo_id=ngo_id,
        name=req.name.strip(),
        email=email_clean,
        crisis_types=req.crisis_types,
        locations=req.locations,
        created_at=created_at_iso,
    )


@router.post(
    "/login",
    summary="Authenticate NGO partner login",
    response_model=NGOResponse,
    status_code=status.HTTP_200_OK,
)
async def login_ngo(req: NGOLoginRequest) -> NGOResponse:
    """
    Validate credentials for an NGO partner:
    1. Fetches NGO profile by email.
    2. Verifies the password using hashlib pbkdf2 comparator.
    3. Returns the full NGO profile on success.
    """
    email_clean = req.email.strip().lower()
    logger.info(f"[NGO Router] Login attempt for email: {email_clean}")

    try:
        ngo_dict = await firebase_service.get_ngo_by_email(email_clean)
    except Exception as exc:
        logger.error(f"[NGO Router] Firebase query error: {exc}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error: {str(exc)}",
        )

    if not ngo_dict:
        logger.warning(f"[NGO Router] No NGO found with email: {email_clean}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    hashed_pw = ngo_dict.get("password_hash")
    if not hashed_pw:
        logger.error(f"[NGO Router] NGO {email_clean} has no password hash stored")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    if not firebase_service.verify_password(req.password, hashed_pw):
        logger.warning(f"[NGO Router] Password verification failed for {email_clean}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    logger.info(f"[NGO Router] NGO '{ngo_dict.get('name')}' authenticated successfully.")

    return NGOResponse(
        ngo_id=ngo_dict.get("ngo_id"),
        name=ngo_dict.get("name"),
        email=ngo_dict.get("email"),
        crisis_types=ngo_dict.get("crisis_types", []),
        locations=ngo_dict.get("locations", []),
        created_at=ngo_dict.get("created_at"),
    )


@router.get("/debug/ngos-list", tags=["Debug"])
async def list_ngos_debug():
    """Debug endpoint: List all registered NGOs (development only)."""
    try:
        from backend.services.firebase_service import get_db
        from backend.config import settings

        db = get_db()
        docs = db.collection(settings.COLLECTION_NGOS).stream()
        ngos = []
        for doc in docs:
            data = doc.to_dict()
            ngos.append({
                "ngo_id": data.get("ngo_id"),
                "name": data.get("name"),
                "email": data.get("email"),
            })
        return {"count": len(ngos), "ngos": ngos}
    except Exception as exc:
        logger.error(f"[Debug] Failed to list NGOs: {exc}")
        return {"error": str(exc)}


