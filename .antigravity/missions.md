# .antigravity/missions.md
# ============================================================
# READY-TO-PASTE ANTIGRAVITY MANAGER VIEW MISSIONS
# Copy each mission prompt into Antigravity Manager View.
# Run them in order. Each generates an Artifact for submission.
# ============================================================

## HOW TO USE THIS FILE

1. Open Antigravity → Manager View
2. Copy the mission prompt from the section below
3. Paste into Manager View and press Enter
4. Wait for Artifact to generate
5. Review Artifact — download it (this is your agent trace log)
6. Move to next mission

---

## MISSION 1 — Build Shared Schemas (Member 1 — Day 1)

```
Read AGENTS.md in the root of this project. Then read shared/schemas.py
if it exists, or create it.

Build a complete Python file at shared/schemas.py containing:
1. RawSubmission Pydantic model (fields from AGENTS.md data contract)
2. CaseObject Pydantic model (all fields including optional ones as None defaults)
3. TraceObject Pydantic model
4. All field validators where needed (phone format, score range 1-10, enum values)

Also create shared/constants.py with:
- CRISIS_TYPES list
- SEVERITY_LEVELS dict with score ranges
- TIME_SENSITIVITY_LEVELS list

Use Pydantic v2. Include type hints for all fields.
Run a quick test to verify models work.
Commit to GitHub using GitHub MCP.
```

---

## MISSION 2 — Build FastAPI Backend (Member 1 — Day 1)

```
Read AGENTS.md and backend/ folder structure.

Build a complete FastAPI backend at backend/main.py with:

Endpoints:
- POST /api/submit-case → accepts RawSubmission, triggers pipeline, returns CaseObject
- GET /api/cases → returns all cases from Supabase dispatch_logs table
- GET /api/cases/{case_id} → returns single case detail
- GET /api/stats → returns {total, pending, critical, dispatched} counts
- GET /api/health → returns {"status": "ok"}

Also build backend/services/pipeline.py that:
- Imports all 5 agents
- Runs them sequentially: intake → validation → severity → impact → dispatch
- Passes CaseObject between each agent
- Returns final CaseObject with full agent_trace

Add CORS middleware for Flutter (allow all origins in dev).
Create requirements.txt with all dependencies.
Create .env.example with all required variables.
Use environment variables from .env file (python-dotenv).
Add error handling for each pipeline step.

Test POST /api/submit-case with a sample Pakistani case.
Commit all files to GitHub using GitHub MCP.
```

---

## MISSION 3 — Build Intake + Validation Agents (Member 2 — Day 1)

```
Read AGENTS.md root file. Then read:
- agents/intake/AGENT.md
- agents/intake/skills/SKILLS.md
- agents/validation/AGENT.md
- agents/validation/skills/SKILLS.md

Build agents/intake/agent.py:
- Function: run_intake_agent(raw_submission: RawSubmission) -> CaseObject
- Import schemas from shared/schemas.py
- Use Gemini API (google-generativeai library) with the prompt template from AGENT.md
- Parse Gemini JSON response safely (json.loads with try/except)
- Implement all rules from SKILLS.md
- Append TraceObject to case.agent_trace before returning
- Handle missing fields with defaults per AGENT.md

Build agents/validation/agent.py:
- Function: run_validation_agent(case: CaseObject) -> CaseObject
- Apply all 5 validation rules from AGENT.md in order
- Implement humanitarian override logic
- Use Gemini for authenticity reasoning
- Append TraceObject

Test both agents with at least 3 test cases:
1. Valid case (normal Pakistani family, Roman Urdu description)
2. Incomplete case (missing phone, short description)
3. Suspicious case (name="test", generic description)

Commit to GitHub using GitHub MCP.
```

---

## MISSION 4 — Build Severity + Impact Agents (Member 3 — Day 1)

```
Read AGENTS.md root file. Then read:
- agents/severity/AGENT.md
- agents/severity/skills/SKILLS.md
- agents/impact/AGENT.md
- agents/impact/skills/SKILLS.md

Build agents/severity/agent.py:
- Function: run_severity_agent(case: CaseObject) -> CaseObject
- Implement the full scoring rubric from AGENT.md (base + additions)
- Use Gemini API for contextual scoring with the prompt template
- Apply language understanding skills for Roman Urdu urgency phrases
- Return score, level, key_insight, scoring_breakdown
- Append TraceObject with full reasoning

Build agents/impact/agent.py:
- Function: run_impact_agent(case: CaseObject) -> CaseObject
- Apply deterministic rules first (no Gemini needed for basic cases)
- Call Gemini for delay_consequence text generation
- Attempt Google Maps MCP geocode if location is recognizable Pakistan address
- Graceful fallback if Maps MCP unavailable
- Append TraceObject

Test with 3 cases:
1. CRITICAL case (medical + zero income + children)
2. MEDIUM case (ration finished, employed family)
3. LOW case (education support, stable income)

Commit to GitHub.
```

---

## MISSION 5 — Build Dispatch Agent (Member 1 — Day 2)

```
Read AGENTS.md root file. Then read:
- agents/dispatch/AGENT.md
- agents/dispatch/skills/SKILLS.md

Build agents/dispatch/agent.py:
- Function: run_dispatch_agent(case: CaseObject) -> CaseObject
- Step 1: Query Supabase volunteers table using Supabase MCP
- Step 2: Use Maps MCP distance_matrix for volunteer-to-applicant distance
- Step 3: Generate ticket_id
- Step 4: Use Gemini to generate Roman Urdu SMS draft
- Step 5: Update Google Sheet row using Sheets MCP (DISPATCHED + all fields)
- Step 6: Insert dispatch log to Supabase using Supabase MCP
- Handle all 4 failure scenarios from AGENT.md
- Append the most detailed TraceObject of all agents

Insert mock volunteer data into Supabase volunteers table (at least 5 volunteers
in different Karachi areas with lat/lng).

Run full end-to-end test:
- Submit a sample case through all 5 agents
- Verify Google Sheet shows BEFORE (PENDING) vs AFTER (DISPATCHED)
- Take screenshot of both states using Playwright MCP

Commit to GitHub.
```

---

## MISSION 6 — Build Flutter Mobile App (Member 4 — Day 2)

```
Read AGENTS.md root file. Read frontend/flutter_app/ folder.

Build a Flutter mobile app with exactly 3 screens:

Screen 1 — Home Screen:
- App name "RaahDo" with subtitle in Roman Urdu: "Madad Ka Raasta"
- Two buttons: "Apply for Help" and "Check Status"
- Simple, clean Material Design 3 UI
- Dark or warm color scheme

Screen 2 — Apply Screen:
- Form fields: Name (text), Phone (text, numeric keyboard),
  Location (text), Crisis Type (dropdown: 5 options),
  Family Size (number), Monthly Income (number),
  Description (multiline text, hint in Roman Urdu)
- Submit button: calls POST /api/submit-case
- On success: show ticket ID in a dialog
- On error: show friendly error message in Roman Urdu

Screen 3 — Status Screen:
- Calls GET /api/cases
- Shows list of cases: ID, name, severity badge (colored chip), status
- Tap a case → show detail sheet with all fields
- Pull-to-refresh

Create frontend/flutter_app/lib/services/api_service.dart:
- All HTTP calls to backend
- API_BASE_URL from constants file

Test all screens. Take screenshots using built-in browser.
Commit to GitHub.
```

---

## MISSION 7 — End-to-End Demo Test (All Members — Day 3)

```
Read AGENTS.md. Read docs/demo-script.md.

Run a complete end-to-end test of the RaahDo system:

1. Open the Flutter app
2. Submit a test case: 
   Name: "Rehana Bibi", Location: "Korangi Karachi",
   Crisis: Medical, Family: 6, Income: 0,
   Description: "Shohar hospital mein hain, 4 bachay hain, khaana nahi,
   operation kal hai. Koi madad karo."

3. Capture: Google Sheet BEFORE state (screenshot)
4. Watch all 5 agents run in sequence (trace in terminal)
5. Capture: Google Sheet AFTER state (screenshot showing DISPATCHED)
6. Check Flutter app status screen shows the case as DISPATCHED
7. Show Streamlit dashboard with the case stats

Generate a final Artifact containing:
- All agent trace logs
- Before/After Sheet screenshots  
- Pipeline execution summary
- Agent reasoning for this specific case

This Artifact is your primary hackathon submission evidence.
```
