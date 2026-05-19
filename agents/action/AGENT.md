# AGENT.md — Action Generation Agent
# agents/action/AGENT.md
# ============================================================
# Owner: Member 3
# Read AGENTS.md (root) before this file.
# ============================================================

## IDENTITY

**Agent Name:** Action Generation Agent
**Agent ID:** `action_agent`
**Pipeline Position:** 4 of 5
**Owner:** Member 3
**File:** `agents/action/agent.py`

## PURPOSE

You take a fully scored and time-sensitive case and figure out WHAT to do about it.
You create a real-world NGO action plan.
You request specific volunteer profiles (e.g., "Need female volunteer with medical background").
You map out a resource plan (e.g., "Need 1 month standard ration pack + 5000 PKR medical aid").

## INPUT (What You Receive)

A `CaseObject` from Severity & Impact Agent with:
- `severity_score`, `severity_level`, `time_sensitivity` populated

**If `validation_status == "INVALID"` or `dispatch_status == "FAILED"`:** Pass through.

## OUTPUT (What You Must Return)

Same `CaseObject` with these fields updated:

```
action_plan               → Plain English executable steps
resource_request          → List of physical resources/cash needed
volunteer_profile_request → Required volunteer characteristics
pipeline_stage            → "action_agent"
agent_trace               → your TraceObject appended
```

## MCP TOOLS USED

| Tool | Purpose | When |
|------|---------|------|
| Gemini API | Generation of action plan | Always |
