# RaahDo — Autonomous NGO Case Intelligence & Dispatch System
**Google Antigravity Hackathon — Challenge 1: Autonomous Content-to-Action Agent**

> "Insight → Priority → Action. No case left behind."

---

## Problem

Pakistani welfare organizations (Saylani, JDC, Edhi) receive hundreds of
applications daily. Manual processing means critical cases — medical emergencies,
starving children — sit in backlogs for days. No triage. No prioritization.
No accountability.

## Solution

RaahDo is an Agentic AI system that automatically processes welfare applications
through a 5-agent pipeline: from raw multilingual input to dispatched volunteer —
in under 10 seconds.

## Architecture

```
Flutter App → FastAPI → 5-Agent Pipeline (Google Antigravity) → Google Sheets + Supabase
```

### Agent Pipeline
| Agent | Role |
|-------|------|
| Intake Agent | Normalizes multilingual input → structured case |
| Validation Agent | Fraud detection + completeness verification |
| Severity Agent | Scores urgency 1-10 using humanitarian rubric |
| Impact Agent | Predicts time sensitivity (IMMEDIATE/TODAY/THIS_WEEK) |
| Dispatch Agent ★ | Assigns volunteer + updates Sheet + logs + SMS |

## Google Antigravity Usage

Antigravity orchestrates the entire agent pipeline:
- Agent sequencing and context passing
- MCP tool integration (Sheets, Supabase, Maps, GitHub)
- Decision tracing and artifact generation
- All agent code written by Antigravity agents via mission prompts

See `.antigravity/missions.md` for all mission prompts.
See `.antigravity/artifacts/` for generated trace logs.

## MCP Tools Used

| MCP Server | Purpose |
|------------|---------|
| Google Sheets MCP | Primary simulation DB — before/after proof |
| Supabase MCP | Volunteers table + dispatch logs |
| Google Maps MCP | Volunteer-to-applicant distance |
| GitHub MCP | Auto-commit agent-written code |
| Playwright MCP | Browser testing + screenshots |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Orchestration | Google Antigravity + Gemini 3.1 Pro |
| Backend | FastAPI (Python) |
| Database | Supabase (PostgreSQL) + Google Sheets |
| Mobile App | Flutter (Dart) |
| Dashboard | Streamlit |
| Hosting | Render.com (free tier) |

## Setup

```bash
# Clone
git clone https://github.com/your-team/raahdo
cd raahdo

# Backend
pip install -r backend/requirements.txt
cp .env.example .env
# Fill in .env values

# Run backend
uvicorn backend.main:app --reload

# Flutter
cd frontend/flutter_app
flutter pub get
flutter run
```

## Environment Variables

See `.env.example` for all required variables.

## Demo

See `docs/demo-script.md` for the 5-minute demo video script.

## Team

| Member | Role |
|--------|------|
| Member 1 | Backend + Orchestration + Dispatch Agent |
| Member 2 | Intake Agent + Validation Agent |
| Member 3 | Severity Agent + Impact Agent |
| Member 4 | Flutter App + Dashboard |
