# 🚀 `AGENTS.md — RAAHDO SYSTEM CONSTITUTION (FINAL PRODUCTION VERSION)`

```md
# AGENTS.md — RaahDo System Constitution
# ============================================================
# SINGLE SOURCE OF TRUTH — DO NOT IGNORE THIS FILE
# ============================================================

## 1. PROJECT IDENTITY

**Name:** RaahDo — Autonomous NGO Case Intelligence & Dispatch System  
**Domain:** Humanitarian / Welfare Tech (Pakistan-first, globally scalable)  
**Challenge:** Google Antigravity Hackathon — Challenge 1  
**Tagline:** Insight → Validate → Prioritize → Act → Deliver  

### CORE PROBLEM
NGOs receive thousands of help requests daily via forms, WhatsApp, email, and manual entries.  
Manual review causes delays, misclassification, and missed critical cases (medical emergencies, hunger, child welfare cases).

RaahDo solves this using an **AI multi-agent decision pipeline** that transforms raw requests into verified, prioritized, and dispatched humanitarian actions.

---

## 2. SYSTEM ARCHITECTURE

```

Flutter App / Web Forms / Email / WhatsApp
↓
FastAPI Gateway (Orchestrator)
↓
6-Agent Pipeline (Sequential)
↓
Storage + Action Layer
↓
Google Sheets + Supabase + SMS + Logs

````

---

## 3. CORE PIPELINE (6 AGENTS ONLY)

1. Intake Agent  
2. Validation Agent  
3. Severity / Insight Agent  
4. Impact Prediction Agent  
5. Action Generation Agent  
6. Dispatch Agent ★ (Execution Engine)

---

## 4. DESIGN PRINCIPLES

### A. Single Responsibility
Each agent performs ONLY one defined function.

### B. Stateless Execution
No persistent memory inside agents. Everything passed via CaseObject.

### C. Strict JSON Contracts
All inputs/outputs MUST follow `shared/schemas.py`.

### D. Fail-Safe System
Invalid cases NEVER reach Dispatch Agent.

### E. Traceability Mandatory
Every agent MUST append a TraceObject.

### F. Multilingual Support
System MUST support:
- Urdu
- Roman Urdu
- English

---

## 5. FOLDER OWNERSHIP MODEL

| Member | Responsibility | Folder |
|--------|---------------|--------|
| Member 1 | FastAPI + Pipeline Orchestration | backend/ |
| Member 2 | Intake + Validation Agents | agents/intake + validation |
| Member 3 | Severity + Impact Agents | agents/severity + impact |
| Member 4 | Flutter App | frontend/flutter_app |

---

## 6. SHARED DATA CONTRACT (CRITICAL)

Source of truth: `shared/schemas.py`

### CASE OBJECT (GLOBAL STANDARD)

```json
{
  "case_id": "uuid",
  "applicant_name": "string",
  "phone": "string",
  "location_normalized": "string",
  "crisis_type": "food | medical | education | emergency_cash | flood_relief",
  "family_size": 0,
  "income_monthly": 0,
  "description_original": "string",
  "description_en": "string",
  "language_detected": "urdu | roman_urdu | english | mixed",
  "has_children": false,
  "medical_emergency": false,

  "validation_status": "VALID | INVALID | NEED_MORE_INFO | null",
  "severity_score": 0.0,
  "severity_level": "LOW | MEDIUM | HIGH | CRITICAL",
  "impact_time": "IMMEDIATE | TODAY | THIS_WEEK",

  "dispatch_status": "PENDING | PROCESSING | DISPATCHED | FAILED",
  "volunteer_assigned": "string | null",
  "ticket_id": "string | null",

  "pipeline_stage": "string",
  "agent_trace": []
}
````

---

## 7. TRACE OBJECT (MANDATORY LOGGING)

Every agent MUST append:

```json
{
  "agent": "string",
  "timestamp": "ISO-8601",
  "action": "string",
  "reasoning": "string",
  "tool_calls": [],
  "output_summary": "string"
}
```

---

## 8. AGENT DEFINITIONS

---

# 8.1 INTAKE AGENT

### ROLE

Convert raw multilingual input into structured CaseObject.

### INPUT

* Flutter form
* Google Forms
* Email text
* WhatsApp text

### OUTPUT

CaseObject (partial filled)

### RESPONSIBILITIES

* Language normalization
* Field extraction
* Missing field detection
* Case ID generation

### RULES

* NEVER decide severity
* NEVER validate authenticity
* ALWAYS preserve raw description

---

# 8.2 VALIDATION AGENT

### ROLE

Detect fraud, duplication, and completeness issues.

### OUTPUT

validation_status + reasons

### RULES

* Do NOT reject humanitarian cases without justification
* Duplicate detection required
* Missing fields must be flagged, not discarded

---

# 8.3 SEVERITY / INSIGHT AGENT

### ROLE

Calculate humanitarian urgency score.

### SCORING SYSTEM

* Medical emergency → +3
* No income → +2
* Children present → +2
* Food shortage → +2

### OUTPUT

severity_score + severity_level + reasoning

---

# 8.4 IMPACT PREDICTION AGENT

### ROLE

Predict urgency timing of case response.

### OUTPUT

IMMEDIATE / TODAY / THIS_WEEK

### FACTORS

* Severity score
* Location accessibility
* Crisis type
* Resource delay risk

---

# 8.5 ACTION GENERATION AGENT

### ROLE

Generate actionable response plan.

### OUTPUT

* recommended actions
* SMS draft
* volunteer request
* resource allocation plan

### RULES

* Must map to real NGO operations
* Must be executable by Dispatch Agent

---

# 8.6 DISPATCH AGENT ★ FINAL ENGINE

### ROLE

Execute real-world simulation actions.

### OPERATIONS

* Assign nearest volunteer (Maps MCP)
* Update Google Sheets status
* Insert Supabase log
* Generate ticket ID
* Send SMS draft

### OUTPUT

* ticket_id
* volunteer_assigned
* DISPATCHED status
* full audit log

---

## 9. MCP TOOL USAGE

| MCP               | Usage                          |
| ----------------- | ------------------------------ |
| Google Sheets MCP | case tracking + status updates |
| Supabase MCP      | permanent logs + audit trail   |
| Google Maps MCP   | nearest volunteer selection    |
| Playwright MCP    | testing only                   |
| GitHub MCP        | auto commits                   |

RULE:
Agents may ONLY use MCP tools explicitly assigned to them.

---

## 10. ORCHESTRATION RULES (FASTAPI + ANTIGRAVITY)

* FastAPI is the ONLY entry point
* Antigravity controls sequencing
* Agents run in strict order
* Each output feeds next agent
* No parallel mutation of same case object

---

## 11. FAILURE HANDLING

If any agent fails:

* set `dispatch_status = FAILED`
* append trace entry
* pass forward with error flag
* NEVER drop case silently

---

## 12. SECURITY RULES

* No CNIC storage in logs
* No sensitive duplication in traces
* Use masked phone numbers if logging externally
* All demo data should be synthetic

---

## 13. TEAM RULES

* No direct push to main branch
* PR required for all changes
* shared/schemas.py cannot be edited without approval
* Each agent must be independently testable

---

## 14. SUCCESS CRITERIA

System is successful only if:

✔ End-to-end case flows without manual intervention
✔ Sheet shows DISPATCHED update
✔ Trace log exists for all 6 agents
✔ Volunteer assignment is simulated correctly
✔ Flutter app reflects updated status

---

## FINAL STATEMENT

RaahDo is not just a chatbot system.

It is an **autonomous humanitarian decision pipeline** that transforms human suffering signals into structured, prioritized, and executed real-world actions using AI agents.

```

---

## If you want next upgrade (important)
I can also generate:

1. :contentReference[oaicite:0]{index=0}
2. :contentReference[oaicite:1]{index=1}
3. `FastAPI routes.py (ready to run)`
4. :contentReference[oaicite:2]{index=2}
5. :contentReference[oaicite:3]{index=3}

Just tell me.

But honestly — your system is now **hackathon-winning level if implemented correctly**.
```