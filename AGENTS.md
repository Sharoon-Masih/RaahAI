AGENTS.md — RaahAI System Constitution
============================================================
SINGLE SOURCE OF TRUTH — DO NOT IGNORE THIS FILE
============================================================
1. PROJECT IDENTITY

Name: RaahAI — Autonomous NGO Case Intelligence & Dispatch System
Domain: Humanitarian / Welfare Tech (Pakistan-first, globally scalable)
Challenge: Google Antigravity Hackathon — Challenge 1
Tagline: Insight → Validate → Prioritize → Act → Deliver

CORE PROBLEM

NGOs receive thousands of help requests daily via forms, WhatsApp, email, and manual entries.
Manual review causes delays, misclassification, and missed critical cases (medical emergencies, hunger, child welfare cases).

RaahAI solves this using an AI multi-agent decision pipeline that transforms raw requests into verified, prioritized, and dispatched humanitarian actions.

2. SYSTEM ARCHITECTURE

Flutter App / Web Forms / Email / Spreadsheets
↓
Google Antigravity (The Core Orchestrator)
↓
5-Agent Pipeline (Sequential execution mapped in Antigravity)
↓
FastAPI Backend (MCP Tool Server & API Gateway)
↓
Storage + Action Layer (Google Sheets, Firebase, SMS, Logs)

3. CORE PIPELINE (5 AGENTS ONLY)
Intake Agent (Email & Spreadsheet processing)
Validation Agent
Severity & Impact Agent (Merged for efficiency)
Action Generation Agent
Dispatch Agent ★ (Execution Engine)
4. DESIGN PRINCIPLES
A. Single Responsibility

Each agent performs ONLY one defined function.

B. Stateless Execution

No persistent memory inside agents. Everything passed via CaseObject.

C. Strict JSON Contracts

All inputs/outputs MUST follow shared/schemas.py.

D. Fail-Safe System

Invalid cases NEVER reach Dispatch Agent.

E. Traceability Mandatory

Every agent MUST append a TraceObject.

F. Multilingual Support

System MUST support:

Urdu
Roman Urdu
English
5. FOLDER OWNERSHIP MODEL & PROMPT MANAGEMENT
Member	Responsibility	Folder
Member 1	FastAPI MCP Server & Endpoints	backend/
Member 2	Intake + Validation Agents	agents/intake/ & agents/validation/
Member 3	Severity/Impact + Action Agents	agents/severity_impact/ & agents/action/
Member 4	Flutter App	frontend/flutter_app/

CRITICAL RULE (prompt.py): Every single agent folder MUST contain a prompt.py file. This file contains the strict system prompts, rules, and boundaries for that specific agent. Antigravity will load these prompts to prevent injection attacks and ensure deterministic behavior.

6. SHARED DATA CONTRACT (CRITICAL)

Source of truth: shared/schemas.py

CASE OBJECT (GLOBAL STANDARD)
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
  "time_sensitivity": "IMMEDIATE | TODAY | THIS_WEEK",

  "dispatch_status": "PENDING | PROCESSING | DISPATCHED | FAILED",
  "volunteer_assigned": "string | null",
  "ticket_id": "string | null",

  "pipeline_stage": "string",
  "agent_trace": []
}
7. TRACE OBJECT (MANDATORY LOGGING)

Every agent MUST append:

{
  "agent": "string",
  "timestamp": "ISO-8601",
  "action": "string",
  "reasoning": "string",
  "tool_calls": [],
  "output_summary": "string"
}
8. AGENT DEFINITIONS
8.1 INTAKE AGENT

ROLE: Convert raw input into structured CaseObject

INPUT:

Google Form
Email

RULES:

Never decide severity
Never validate authenticity
Always preserve raw input
8.2 VALIDATION AGENT

Detect fraud, duplication, missing fields

MUST NOT reject without reason
Must flag issues, not delete cases
8.3 SEVERITY & IMPACT AGENT

Compute urgency + impact time

Signals:

Medical emergency → +3
No income → +2
Children → +2
Food shortage → +2

Output: severity_score + severity_level + impact_time

8.4 ACTION GENERATION AGENT

Creates real-world NGO action plan

Volunteer request
Resource plan

Must be executable

8.5 DISPATCH AGENT ★ FINAL ENGINE

Executes actions via MCP tools

Google Sheets update
Volunteer assignment
Ticket generation
SMS sending
9. MCP TOOL USAGE
Tool	Usage
Google Sheets MCP	case tracking
Firebase Firestore	audit logs
Google Maps MCP	volunteer location
Playwright MCP	testing
GitHub MCP	commits

RULE: Only assigned agents can use assigned tools

10. ORCHESTRATION RULES
Google Antigravity = ONLY orchestrator
FastAPI = MCP tool server
Sequential pipeline only
No parallel mutation of CaseObject
11. FAILURE HANDLING
Never drop cases
Always mark FAILED
Always append trace
12. SECURITY RULES
No CNIC storage
Mask sensitive data
Use synthetic data for demos
13. TEAM RULES
No direct main branch push
PR required
schemas.py locked
agents independently testable
14. SUCCESS CRITERIA

✔ End-to-end automation
✔ Google Sheet updated to DISPATCHED
✔ Full trace logs for all agents
✔ Volunteer assignment works
✔ Flutter dashboard reflects live status

FINAL STATEMENT

RaahAI is not just a chatbot system. It is an autonomous humanitarian decision pipeline that transforms human suffering signals into structured, prioritized, and executed real-world actions using AI agents.