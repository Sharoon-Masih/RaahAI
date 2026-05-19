# shared/schemas.py
# ============================================================
# SINGLE SOURCE OF TRUTH — All Pydantic models for RaahAI
# DO NOT DUPLICATE these in agent files — always import from here.
# DO NOT MODIFY without team consensus (Member 1 owns this file).
# DATABASE: Firebase Firestore ONLY — no SQL, no Supabase.
# ============================================================

from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Any
from enum import Enum
import uuid


# ── ENUMS ──────────────────────────────────────────────────

class CrisisType(str, Enum):
    FOOD = "food"
    MEDICAL = "medical"
    EDUCATION = "education"
    EMERGENCY_CASH = "emergency_cash"
    FLOOD_RELIEF = "flood_relief"

class ValidationStatus(str, Enum):
    VALID = "VALID"
    NEED_MORE_INFO = "NEED_MORE_INFO"
    INVALID = "INVALID"

class SeverityLevel(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

class TimeSensitivity(str, Enum):
    IMMEDIATE = "IMMEDIATE"
    TODAY = "TODAY"
    THIS_WEEK = "THIS_WEEK"

class DispatchStatus(str, Enum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    DISPATCHED = "DISPATCHED"
    FAILED = "FAILED"
    PENDING_MANUAL = "PENDING_MANUAL"

class SubmissionSource(str, Enum):
    FLUTTER_APP = "flutter_app"
    WEB_FORM = "web_form"
    STAFF_ENTRY = "staff_entry"

class LanguageDetected(str, Enum):
    URDU = "urdu"
    ROMAN_URDU = "roman_urdu"
    ENGLISH = "english"
    MIXED = "mixed"
    UNKNOWN = "unknown"


# ── RAW SUBMISSION (Flutter → FastAPI) ──────────────────────

class RawSubmission(BaseModel):
    """Input model from Flutter app form submission."""
    applicant_name: str = Field(..., min_length=1, description="Applicant full name")
    phone: str = Field(..., description="Pakistan phone number")
    location_text: str = Field(..., description="Location as typed by user")
    crisis_type: CrisisType = Field(..., description="Type of assistance needed")
    family_size: Optional[int] = Field(default=1, ge=1, le=30)
    income_monthly: Optional[int] = Field(default=0, ge=0)
    description: Optional[str] = Field(default="", description="Free text in any language")
    submission_source: SubmissionSource = Field(default=SubmissionSource.FLUTTER_APP)

    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v: str) -> str:
        cleaned = v.replace(' ', '').replace('-', '').replace('(', '').replace(')', '')
        return cleaned


# ── TRACE OBJECT (Appended by each agent) ──────────────────

class TraceObject(BaseModel):
    """Agent reasoning trace entry — appended by each agent."""
    agent: str
    timestamp: str
    action: str
    reasoning: str
    tool_calls: List[str] = Field(default_factory=list)
    output_summary: str


# ── CASE OBJECT (Between agents + final output) ─────────────

class CaseObject(BaseModel):
    """
    The central data object that flows through the entire pipeline.
    Each agent receives this, adds its fields, and passes it on.
    Only Dispatch Agent writes to external systems (via FastAPI → Firebase).
    """

    # ── Core Identity (set by Intake Agent)
    case_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    applicant_name: Optional[str] = None          # null if not found in input
    phone: Optional[str] = None                   # null if no valid PK number
    location_normalized: Optional[str] = None     # null if unrecognizable
    crisis_type: Optional[str] = None
    family_size: int = 1
    income_monthly: int = 0

    # ── Inferred Flags (set by Intake Agent)
    has_children: bool = False
    medical_emergency: bool = False
    language_detected: Optional[LanguageDetected] = None
    description_en: str = ""
    description_original: str = ""

    # ── Validation (set by Validation Agent)
    validation_status: Optional[ValidationStatus] = None
    validation_reasons: List[str] = Field(default_factory=list)
    fraud_signals: List[str] = Field(default_factory=list)

    # ── Severity & Impact (set by SeverityImpact Agent)
    severity_score: Optional[float] = Field(default=None, ge=0.0, le=10.0)
    severity_level: Optional[SeverityLevel] = None
    key_insight: Optional[str] = None
    scoring_breakdown: Optional[dict] = None
    compound_crisis_detected: bool = False
    time_sensitivity: Optional[TimeSensitivity] = None
    delay_consequence: Optional[str] = None
    location_risk_factor: Optional[str] = None

    # ── Action Generation (set by Action Agent)
    action_plan: Optional[str] = None
    resource_request: Optional[str] = None
    volunteer_profile_request: Optional[str] = None

    # ── Dispatch (set by Dispatch Agent)
    volunteer_assigned: Optional[str] = None
    ticket_id: Optional[str] = None
    sms_draft: Optional[str] = None
    dispatch_status: DispatchStatus = DispatchStatus.PENDING

    # ── Pipeline Metadata
    pipeline_stage: str = "raw"
    submission_source: Optional[str] = None
    agent_trace: List[TraceObject] = Field(default_factory=list)

    def append_trace(self, trace: TraceObject) -> None:
        """Convenience method to append a trace entry."""
        self.agent_trace.append(trace)

    def is_processable(self) -> bool:
        """Check if case should continue through pipeline."""
        return self.dispatch_status != DispatchStatus.FAILED

    def is_critical(self) -> bool:
        """Check if case requires immediate action."""
        return (
            self.severity_level == SeverityLevel.CRITICAL or
            self.time_sensitivity == TimeSensitivity.IMMEDIATE
        )

    def to_firestore_dict(self) -> dict:
        """
        Serialize CaseObject to a Firestore-safe dict.
        Converts Enum values to their string equivalents.
        Converts nested TraceObject list to plain dicts.
        """
        data = self.model_dump(mode="json")
        # Flatten enums to their values (Pydantic mode='json' handles this)
        # Convert agent_trace TraceObjects to dicts
        data["agent_trace"] = [
            t if isinstance(t, dict) else t.model_dump(mode="json")
            for t in self.agent_trace
        ]
        return data


# ── API RESPONSE MODELS ─────────────────────────────────────

class SubmitCaseResponse(BaseModel):
    success: bool
    case_id: str
    ticket_id: Optional[str]
    dispatch_status: str
    severity_level: Optional[str]
    message: str

class StatsResponse(BaseModel):
    total: int
    pending: int
    processing: int
    dispatched: int
    failed: int
    critical: int
