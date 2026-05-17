# SKILLS.md — Intake Agent
# agents/intake/skills/SKILLS.md
# ============================================================

## SKILL SET

### SKILL 1: Multilingual Understanding
**What:** Detect and handle Urdu, Roman Urdu, English, and mixed text.
**How:**
- Roman Urdu keywords to watch: "bacha", "bachi", "khaana", "marz",
  "hospital", "dawai", "nahi", "meri", "shohar", "ghar", "masjid",
  "ration", "garib", "madad", "zaroorat", "emergency", "operation"
- Urdu script detection: check for Unicode range U+0600–U+06FF
- Mixed: both scripts or Roman Urdu + English in same text
**Output field:** `language_detected`

---

### SKILL 2: Data Normalization
**What:** Clean and standardize all input fields.
**Rules:**
- Phone numbers: strip spaces, dashes, parentheses. Prepend +92 if starts with 03.
  Example: "0300-1234567" → "+923001234567"
- Names: title case, strip extra whitespace
- Income: if string like "nahi" or "zero" or "koi nahi" → set to 0
- Family size: if 0 or missing → default to 1
**Output fields:** `phone`, `applicant_name`, `income_monthly`, `family_size`

---

### SKILL 3: Field Extraction
**What:** Extract implicit information from description text.
**Rules for `medical_emergency` = true:**
  - English keywords: hospital, surgery, operation, medicine, sick, ill, emergency, dialysis, cancer, fever
  - Roman Urdu keywords: hospital, dawai, operation, bemar, bukhar, dawa, bimari, ilaj
  - Urdu keywords: ہسپتال، دوائی، آپریشن، بیمار
**Rules for `has_children` = true:**
  - family_size >= 3 AND income_monthly == 0
  - OR description mentions: child, children, bacha, bachi, beta, beti, school

---

### SKILL 4: Missing Data Detection
**What:** Identify and flag incomplete submissions.
**Required fields:** applicant_name, phone, location_text, crisis_type
**Optional fields:** family_size, income_monthly, description
**If required field missing:** note in trace, use sensible default, do NOT block pipeline.
**Output:** trace entry noting missing fields

---

### SKILL 5: Structuring Unstructured Input
**What:** Convert free-text descriptions into normalized English summary.
**Rules:**
- Maximum 3 sentences
- Must include: crisis type, family situation, urgency signals
- Must be factual — do not add information not in original
- Preserve original in `description_original`
