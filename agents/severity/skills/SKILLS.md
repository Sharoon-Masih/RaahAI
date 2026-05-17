# SKILLS.md — Severity / Insight Agent
# agents/severity/skills/SKILLS.md
# ============================================================

## SKILL SET

### SKILL 1: Risk Scoring
**What:** Calculate a numeric severity score using weighted rubric.
**Method:** Base score (from crisis type) + additive multipliers (from conditions).
**Key principle:** Never score mechanically. Read the description and let
context adjust the score. A 6.0 from rubric that reads as a 9.0 situation
should be adjusted upward with explicit reasoning in trace.
**Output:** severity_score (float, 1.0–10.0)

---

### SKILL 2: Humanitarian Prioritization
**What:** Rank and differentiate cases that seem similar on surface.
**Differentiators:**
- Time sensitivity: "kal operation" (surgery tomorrow) > "kuch hafte se bemar" (sick for weeks)
- Dependency: family of 6 with 4 children > single adult
- Resource access: "koi madad nahi" (no help available) > "relatives help karte hain" (relatives help)
- Compound crises: medical + food + no home = multiply urgency
**Output:** key_insight string explaining differentiation

---

### SKILL 3: Emergency Classification
**What:** Assign categorical severity level from score.
**Mapping:** 1–3.9 → LOW, 4–5.9 → MEDIUM, 6–7.9 → HIGH, 8–10 → CRITICAL
**CRITICAL must-have conditions:**
- Score >= 8.0 AND at least one of: medical_emergency, children + zero income,
  flood-displaced family, "haven't eaten in 3+ days"
**Output:** severity_level (string enum)

---

### SKILL 4: Impact Evaluation
**What:** Identify whether delay causes irreversible harm.
**Irreversible harm signals:**
- Medical: missed surgery, untreated infection, dialysis gap
- Food: multi-day starvation, especially with children
- Shelter: flood exposure, no roof in winter/monsoon
**Output:** compound_crisis_detected (boolean), reflected in score

---

### SKILL 5: Contextual Language Understanding
**What:** Extract urgency from Urdu/Roman Urdu description text.
**Key urgency phrases and their weight:**
| Phrase | Meaning | Weight |
|--------|---------|--------|
| "3/4/5 din se khaana nahi" | days without food | HIGH |
| "kal operation hai" | surgery tomorrow | CRITICAL |
| "ghar nahi hai" | homeless | HIGH |
| "koi nahi hai" | no support network | MEDIUM |
| "bachay school nahi ja rahe" | children not in school | MEDIUM |
| "bijli/paani nahi" | no utilities | MEDIUM |
| "shohar hospital mein" | spouse hospitalized | HIGH |
| "akela/akeli hoon" | alone, no family | MEDIUM |
