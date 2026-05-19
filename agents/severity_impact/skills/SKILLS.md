# SKILLS.md — Severity & Impact Agent Rubric
# ============================================================
# This is the exact rubric injected into the Gemini prompt.

## Base Score by Crisis Type
- food / ration: 5.0
- medical: 6.0
- emergency_cash: 4.5
- education: 3.5
- flood_relief: 6.5

## Multipliers and Additions
- income_monthly == 0: +2.5
- income_monthly < 5000: +1.5
- medical_emergency == true: +2.5
- has_children == true: +1.5
- family_size >= 5: +1.0
- family_size >= 8: +1.5
- description mentions "3 din", "4 din": +2.0
- description mentions "kal operation", "surgery tomorrow": +2.0
- description mentions "ghar nahi": +1.5
- description mentions "koi nahi": +1.0
- flood_relief AND income == 0: +1.5

## Severity Level Mapping
- 1.0 – 3.9: LOW
- 4.0 – 5.9: MEDIUM
- 6.0 – 7.9: HIGH
- 8.0 – 10.0: CRITICAL

## Time Sensitivity Rules
- severity_level == "CRITICAL": IMMEDIATE
- medical_emergency == true: IMMEDIATE
- severity_score >= 8.0: IMMEDIATE
- severity_level == "HIGH": TODAY
- severity_score >= 6.0: TODAY
- severity_level == "MEDIUM": TODAY
- severity_level == "LOW": THIS_WEEK
