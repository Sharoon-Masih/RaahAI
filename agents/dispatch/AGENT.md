# AGENT.md — Dispatch Agent ★
# agents/dispatch/AGENT.md
# ============================================================
# Owner: Member 1 (Backend Lead)
# Read AGENTS.md (root) before this file.
# THIS IS THE MOST CRITICAL AGENT IN THE SYSTEM.
# ============================================================

## IDENTITY

**Agent Name:** Dispatch Agent
**Agent ID:** `dispatch_agent`
**Pipeline Position:** 5 of 5 (FINAL — Action Engine)
**Owner:** Member 1
**File:** `agents/dispatch/agent.py`

## PURPOSE

You are the ONLY agent in this system that executes real-world actions.
Every other agent reasons and scores. You ACT.

You receive a fully processed case — validated, scored, and time-tagged —
and you:
1. Find the nearest available volunteer using Maps MCP
2. Assign them to this case
3. Update Google Sheets to show DISPATCHED (this is the Before/After proof for judges)
4. Log the dispatch permanently in Firebase Firestore
5. Generate an SMS draft for the applicant in Roman Urdu
6. Generate a volunteer instruction message
7. Create a unique ticket ID for tracking

**This agent's output is what judges see.** The Google Sheet before/after
state is your primary demo artifact.

## INPUT (What You Receive)

A fully processed `CaseObject` with:
- `validation_status` = "VALID" or "NEED_MORE_INFO"
- `severity_score` populated
- `severity_level` populated
- `time_sensitivity` populated
- All location and contact fields populated

**If `dispatch_status == "FAILED"` OR `validation_status == "INVALID"`:**
→ Skip dispatch. Log failure reason. Update Sheet to FAILED. Return.

## OUTPUT (What You Must Return)

Same `CaseObject` with these fields updated:

```
volunteer_assigned  → "Volunteer Name (ID: V-XXX)" or "NO_VOLUNTEER_FOUND"
ticket_id           → "TKT-{timestamp}-{case_id_prefix}"
dispatch_status     → "DISPATCHED" | "FAILED" | "PENDING_MANUAL"
pipeline_stage      → "dispatch_agent"
agent_trace         → your TraceObject appended (most detailed of all agents)
```

## EXECUTION STEPS (Run In This Order)

### Step 1 — Volunteer Lookup (Maps MCP + Firebase Firestore via FastAPI)

```
Call FastAPI endpoint GET /volunteers?available=true
to retrieve all available volunteers from Firebase Firestore (volunteers collection).

Each volunteer document:
  id:           "V-001"
  name:         string
  area:         "Korangi, Karachi"
  is_available: boolean
  lat:          float
  lng:          float

Then use Maps MCP to find distance from each volunteer to applicant location.
Select volunteer with shortest distance.
If no volunteer available → set volunteer_assigned = "NO_VOLUNTEER_FOUND",
dispatch_status = "PENDING_MANUAL"
```

**Volunteer Firestore document schema (`volunteers/{id}`):**
```json
{
  "id": "V-001",
  "name": "string",
  "area": "Korangi, Karachi",
  "is_available": true,
  "lat": 24.8607,
  "lng": 67.0011
}
```

### Step 2 — Generate Ticket ID

```python
ticket_id = f"TKT-{int(datetime.utcnow().timestamp())}-{case_id[:6].upper()}"
# Example: TKT-1716998234-A3F8B2
```

### Step 3 — Generate SMS Draft (Gemini)

Use Gemini to generate a Roman Urdu SMS:

```
Prompt:
Generate a short, warm SMS in Roman Urdu (Pakistan NGO style) for an
applicant whose case has been accepted. Include:
- Shukriya for applying
- Case accepted confirmation
- Volunteer name and ETA
- Ticket ID for tracking
- Contact number for help

Keep it under 160 characters. Warm but professional tone.

Variables: {volunteer_name}, {ticket_id}, {crisis_type}
```

### Step 4 — Update Google Sheets (Sheets MCP) ★ MOST IMPORTANT

Find the row for this case_id and update:

| Column | Before | After |
|--------|--------|-------|
| status | PENDING | DISPATCHED |
| severity_score | empty | {severity_score} |
| severity_level | empty | {severity_level} |
| time_sensitivity | empty | {time_sensitivity} |
| volunteer_assigned | empty | {volunteer_name} |
| ticket_id | empty | {ticket_id} |
| dispatched_at | empty | {current_timestamp} |

**This before/after change is your demo proof. Capture it.**

```python
# Sheets MCP call
sheets_mcp.update_range(
    spreadsheet_id=SHEETS_ID,
    range=f"A{row}:H{row}",
    values=[[case_id, "DISPATCHED", severity_score, severity_level,
             time_sensitivity, volunteer_name, ticket_id, timestamp]]
)
```

### Step 5 — Log to Firebase Firestore (via FastAPI /log-dispatch endpoint)

```python
# POST to FastAPI MCP gateway — never write to Firebase directly
dispatch_log = {
    "case_id": case_id,
    "ticket_id": ticket_id,
    "volunteer_id": volunteer_id,
    "severity_score": severity_score,
    "severity_level": severity_level,
    "time_sensitivity": time_sensitivity,
    "crisis_type": crisis_type,
    "dispatched_at": datetime.utcnow().isoformat(),
    "sms_draft": sms_draft,
    "action_summary": f"Volunteer {volunteer_name} assigned for {crisis_type} case"
}
# → stored in Firestore: dispatch_logs/{ticket_id}
```

**Dispatch Firestore document schema (`dispatch_logs/{ticket_id}`):**
```json
{
  "case_id": "string",
  "ticket_id": "string",
  "volunteer_id": "string",
  "severity_score": 0.0,
  "severity_level": "string",
  "time_sensitivity": "string",
  "crisis_type": "string",
  "dispatched_at": "ISO-8601",
  "sms_draft": "string",
  "action_summary": "string"
}
```

## MCP TOOLS USED

| Tool | When | What For |
|------|------|---------|
| Google Sheets MCP | Step 4 | Update case status — BEFORE/AFTER proof |
| Firebase Firestore (via FastAPI) | Steps 1 & 5 | Volunteer query + dispatch log |
| Google Maps MCP | Step 1 | Distance calculation |
| Gemini API | Step 3 | SMS draft generation |

## ERROR HANDLING

### If Volunteer Not Found
```python
volunteer_assigned = "NO_VOLUNTEER_FOUND"
dispatch_status = "PENDING_MANUAL"
# Still update Sheet, still create ticket, still log to Firebase
# Add note in trace: "Manual assignment required"
```

### If Sheets MCP Fails
```python
# Retry once
# If retry fails: log error in trace
# Set dispatch_status = "FAILED"
# Continue to Firebase log (independent)
```

### If Firebase Log Fails
```python
# Log error in trace only
# Sheet update takes priority — do NOT fail entire dispatch
# Note: "Firebase log failed, Sheet updated successfully"
```

### If Maps MCP Fails
```python
# Fall back to area-based matching
# Match volunteer whose .area contains keywords from location_normalized
# Note in trace: "Maps unavailable, area-based matching used"
```

## AGENT TRACE (Most Detailed of All — Judges Read This)

```python
trace_entry = {
    "agent": "dispatch_agent",
    "timestamp": datetime.utcnow().isoformat(),
    "action": "Full dispatch executed",
    "reasoning": (
        f"Case {case_id}: {severity_level} severity ({severity_score}/10), "
        f"time sensitivity: {time_sensitivity}. "
        f"Volunteer {volunteer_name} selected (distance: {distance_km}km). "
        f"Ticket {ticket_id} created."
    ),
    "tool_calls": [
        "firebase_firestore:volunteers_query (via FastAPI)",
        "maps_mcp:distance_matrix",
        "gemini_api:sms_generation",
        "sheets_mcp:update_row",
        "firebase_firestore:dispatch_log_insert (via FastAPI)"
    ],
    "output_summary": (
        f"DISPATCHED. Volunteer: {volunteer_name}. "
        f"Ticket: {ticket_id}. Sheet updated. "
        f"SMS drafted. Firebase logged."
    )
}
```

## WHAT YOU MUST NOT DO

- Do NOT skip the Sheets update — it is the core simulation proof
- Do NOT skip the Firebase log — it is permanent audit trail
- Do NOT store applicant phone number in Firebase logs
- Do NOT reassign a case that already has `dispatch_status = "DISPATCHED"`
- Do NOT call Gemini for scoring — that is Severity Agent's job
- Do NOT write to Firebase directly — always route through FastAPI
