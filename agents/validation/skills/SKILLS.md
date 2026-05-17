# SKILLS.md — Validation Agent
# agents/validation/skills/SKILLS.md
# ============================================================

## SKILL SET

### SKILL 1: Data Validation
**What:** Verify structural integrity and completeness of case data.
**Checks:**
- Type validation: family_size is integer, income is integer
- Length validation: description > 5 words, name > 2 characters
- Format validation: phone matches Pakistan number pattern
- Enum validation: crisis_type is one of allowed values
**Outputs:** validation_status, validation_reasons[]

---

### SKILL 2: Fraud Detection Signals
**What:** Identify patterns that suggest test, spam, or fraudulent entries.
**Signals (any one → NEED_MORE_INFO, multiple → consider INVALID):**
- Name is "test", "abc", "xyz", "aaa", numeric only
- Description is single word, generic greeting, or repeated characters
- All numeric fields are exactly 0 or exactly 1 (suspicious uniformity)
- Description and crisis_type completely mismatched
**Note:** Always check against humanitarian override before setting INVALID.

---

### SKILL 3: Consistency Checking
**What:** Verify fields are logically consistent with each other.
**Checks:**
- medical_emergency vs crisis_type alignment
- has_children vs family_size alignment
- income_monthly vs stated poverty level in description
- location vs crisis_type (flood relief in non-flood area = note, not block)
**Output:** consistency_notes[]

---

### SKILL 4: Completeness Verification
**What:** Identify which required fields are missing or empty.
**Required:** name, phone, location, crisis_type
**Preferred:** description (at least 5 words), family_size
**Action:** note missing fields in trace, set NEED_MORE_INFO, never block

---

### SKILL 5: Humanitarian Override Logic
**What:** Ensure no genuine crisis case is blocked.
**Override triggers (auto-pass even if other checks fail):**
- medical_emergency = true → override to VALID or NEED_MORE_INFO maximum
- has_children = true AND income = 0 → override to VALID or NEED_MORE_INFO
- crisis_type = "flood_relief" → high probability genuine, lean VALID
**Reasoning:** A genuine person in crisis may fill the form hurriedly,
with poor spelling, incomplete info. That is normal. Block only bots.
