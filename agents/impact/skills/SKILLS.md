# SKILLS.md — Impact Prediction Agent
# agents/impact/skills/SKILLS.md
# ============================================================

## SKILL SET

### SKILL 1: Time Sensitivity Analysis
**What:** Map severity data to response time window.
**Method:** Deterministic rule-based first, then Gemini refinement.
**Priority order:** medical_emergency flag > severity_score > location factor
**Output:** time_sensitivity (IMMEDIATE | TODAY | THIS_WEEK)

---

### SKILL 2: Location-Based Urgency Adjustment
**What:** Identify if location increases urgency (remote = longer help arrival time).
**Pakistan context:**
- Rural Sindh, Balochistan, KP interior → HIGH location risk
- Karachi, Lahore, Islamabad, major cities → LOW location risk
- Flood-prone areas (Dadu, Sukkur, Dera Ghazi Khan) → HIGH location risk
**Method:** If Maps MCP available → geocode + check. If not → use keyword matching on location_normalized.
**Keywords for HIGH risk:** "village", "gaon", "deh", "taluka", interior district names
**Output:** location_risk_factor (high | medium | low | unknown)

---

### SKILL 3: Delay Risk Prediction
**What:** Articulate the real-world consequence of NOT acting by the time window.
**Template:** "If this case is not addressed [IMMEDIATELY/TODAY/THIS WEEK],
[specific consequence: surgery missed / children go another day without food / ...]"
**Must be specific** — not generic. Use actual case details.
**Output:** delay_consequence (string)

---

### SKILL 4: Compound Urgency Detection
**What:** Identify cases where multiple time-sensitive factors overlap.
**Compound patterns that auto-trigger IMMEDIATE:**
- Medical + zero income + children
- Flood displacement + no shelter + family
- Zero income + no food + 3+ days elapsed
**Output:** reflected in time_sensitivity upgrade
