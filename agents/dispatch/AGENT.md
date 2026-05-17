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
4. Log the dispatch permanently in Supabase
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

### Step 1 — Volunteer Lookup (Maps MCP + Supabase MCP)

```
Query Supabase volunteers table:
  SELECT id, name, phone, area, is_available
  FROM volunteers
  WHERE is_available = true
  ORDER BY area

Then use Maps MCP to find distance from each volunteer to applicant location.
Select volunteer with shortest distance.
If no volunteer available → set volunteer_assigned = "NO_VOLUNTEER_FOUND",
dispatch_status = "PENDING_MANUAL"
```

**Volunteer table schema (Supabase):**
```sql
volunteers (
  id          TEXT PRIMARY KEY,   -- "V-001"
  name        TEXT,
  phone       TEXT,
  area        TEXT,               -- "Korangi, Karachi"
  is_available BOOLEAN,
  lat         FLOAT,
  lng         FLOAT
)
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

### Step 5 — Log to Supabase (Supabase MCP)

```python
# Supabase MCP call
supabase_mcp.insert(
    table="dispatch_logs",
    record={
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
)
```

**Dispatch logs table schema (Supabase):**
```sql
dispatch_logs (
  id              SERIAL PRIMARY KEY,
  case_id         TEXT,
  ticket_id       TEXT UNIQUE,
  volunteer_id    TEXT,
  severity_score  FLOAT,
  severity_level  TEXT,
  time_sensitivity TEXT,
  crisis_type     TEXT,
  dispatched_at   TIMESTAMPTZ,
  sms_draft       TEXT,
  action_summary  TEXT
)
```

## MCP TOOLS USED

| Tool | When | What For |
|------|------|---------|
| Google Sheets MCP | Step 4 | Update case status — BEFORE/AFTER proof |
| Supabase MCP | Steps 1 & 5 | Volunteer query + dispatch log |
| Google Maps MCP | Step 1 | Distance calculation |
| Gemini API | Step 3 | SMS draft generation |

## ERROR HANDLING

### If Volunteer Not Found
```python
volunteer_assigned = "NO_VOLUNTEER_FOUND"
dispatch_status = "PENDING_MANUAL"
# Still update Sheet, still create ticket, still log to Supabase
# Add note in trace: "Manual assignment required"
```

### If Sheets MCP Fails
```python
# Retry once
# If retry fails: log error in trace
# Set dispatch_status = "FAILED"
# Continue to Supabase log (independent)
```

### If Supabase MCP Fails
```python
# Log error in trace only
# Sheet update takes priority — do NOT fail entire dispatch
# Note: "Supabase log failed, Sheet updated successfully"
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
        "supabase_mcp:volunteers_query",
        "maps_mcp:distance_matrix",
        "gemini_api:sms_generation",
        "sheets_mcp:update_row",
        "supabase_mcp:dispatch_log_insert"
    ],
    "output_summary": (
        f"DISPATCHED. Volunteer: {volunteer_name}. "
        f"Ticket: {ticket_id}. Sheet updated. "
        f"SMS drafted. Supabase logged."
    )
}
```

## WHAT YOU MUST NOT DO

- Do NOT skip the Sheets update — it is the core simulation proof
- Do NOT skip the Supabase log — it is permanent audit trail
- Do NOT store applicant phone number in Supabase logs
- Do NOT reassign a case that already has `dispatch_status = "DISPATCHED"`
- Do NOT call Gemini for scoring — that is Severity Agent's job
