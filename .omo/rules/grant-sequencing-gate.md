---
paths:
  - "proposal/**"
  - "grants/**"
  - "**/*aims*"
  - "**/*specific-aims*"
  - "**/*significance*"
  - "**/*innovation*"
  - "**/*approach*"
---

<!-- GENERATED from .claude/rules/grant-sequencing-gate.md by scripts/generate-omo-rules.sh — DO NOT EDIT -->

# Grant Writing Sequencing Gate

Mandatory order for grant proposal work. Treat each numbered step as a hard gate unless marked optional.

1. **Outline** — `/grant-planning`, then `/grant-outline`. HARD GATE: never invoke a `/draft-*` skill before an outline exists. If missing, STOP and create it first.

2. **Draft** — `/draft-specific-aims` → `/draft-significance` → `/draft-innovation` → `/draft-approach`, in that order, each following the outline. Sequential drafting is the default; draft in parallel only if the outline is unusually detailed and the author is experienced.

3. **Coherence check** — `/coherence-check`. HARD GATE: run after 2+ sections are drafted, before editing begins.

4. **Edit** — `/edit-with-context`, only after step 3. Never edit a paragraph in isolation from its surrounding context.

5. **Mid-draft outline change**: if structure needs to change while drafting, STOP drafting, update the outline first, then resume from step 2.

6. **Review** — `grant-reviewer` agent, after editing is complete. Address feedback via `/edit-with-context` and re-run the coherence check if changes are major, before submission.

Skipping step 1 or step 3 is the most common failure mode; both are hard gates, not suggestions.
