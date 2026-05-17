# SKILLS.md — Dispatch Agent
# agents/dispatch/skills/SKILLS.md
# ============================================================

## SKILL SET

### SKILL 1: Volunteer Matching
**What:** Find the best available volunteer for this case.
**Method:**
  1. Query Supabase for all available volunteers (is_available = true)
  2. Use Maps MCP to calculate distance from each to applicant location
  3. Select shortest distance
  4. If tie → prefer volunteer whose area matches applicant's area keyword
**Fallback (no Maps):** string match volunteer.area vs location_normalized keywords
**Output:** volunteer_id, volunteer_name, distance_km

---

### SKILL 2: Distance-Based Assignment
**What:** Prioritize proximity for fastest response.
**Pakistan context:**
- Within 2 km → ideal
- 2–5 km → acceptable
- 5–10 km → flag in trace, assign anyway
- >10 km → assign but note "long distance, consider alternate"
**IMMEDIATE cases:** accept any distance
**THIS_WEEK cases:** prefer <5km only
**Output:** distance_km, assignment_note

---

### SKILL 3: Action Execution
**What:** Coordinate all MCP tool calls in correct sequence.
**Sequence (must be in this order):**
  1. Supabase query (get volunteers)
  2. Maps distance (find nearest)
  3. Generate ticket_id
  4. Gemini SMS draft
  5. Sheets update (before/after proof)
  6. Supabase log (audit trail)
**Never skip steps 5 and 6.** They are non-optional.

---

### SKILL 4: System Logging
**What:** Create complete, auditable records of every dispatch.
**Principles:**
- Every action must be logged — even failures
- Ticket IDs are globally unique (timestamp-based)
- Dispatch log is permanent — never delete, only append
- Trace must include all 5+ tool calls explicitly listed
**Output:** dispatch_logs record in Supabase

---

### SKILL 5: SMS / Communication Generation
**What:** Draft applicant-facing messages in appropriate language.
**Style guidelines:**
- Warm, reassuring tone — this person is in crisis
- Roman Urdu preferred (most accessible for Pakistan audience)
- Include: shukriya, confirmation, volunteer name, ETA if possible, ticket ID
- Max 160 characters for SMS, 300 for WhatsApp
- Never include applicant's phone number in draft
**Sample format:**
  "Assalam o Alaikum! Aapki application accept ho gayi. Volunteer [Name]
  aap ke paas aa rahe hain. Ticket: [ID]. Saylani RaahDo Team."
