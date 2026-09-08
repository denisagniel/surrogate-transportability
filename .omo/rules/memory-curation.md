---
paths:
  - "MEMORY.md"
---

<!-- GENERATED from .claude/rules/memory-curation.md by scripts/generate-omo-rules.sh — DO NOT EDIT -->

# Memory Curation Protocol

## What Goes in MEMORY.md

**ONLY explicit learnings:**
- User issues `/learn [topic] [wrong → right]` command
- Agent is explicitly corrected and user confirms it should be remembered
- Pattern identified across 3+ sessions that prevents repeated mistakes

**NEVER auto-append:**
- Session summaries or progress updates
- One-off decisions for current task
- Temporary workarounds or experiments
- "Nice to know" facts that don't prevent future mistakes

---

## Entry Format

```
[LEARN:category] wrong → right
```

**Categories:** workflow, design, documentation, files, governance, skills, memory, meta, context-efficiency, constitution, quality, testing, R, LaTeX, git

**Style:**
- Concise (1-2 lines)
- Actionable (clear wrong → right)
- Generalizable (not task-specific)

---

## Size Limit

Keep under **200 lines**. When approaching limit:
1. Merge related entries
2. Remove entries that haven't been referenced in 10+ sessions
3. Move machine-specific learnings to `.claude/state/personal-memory.md` (gitignored)
4. Move domain-specific patterns to appropriate rule files

> **200 is the single canonical cap**, set 2026-08-13. It previously read 100 here, `<80` under
> "When to Prune", `~200` in `meta-governance.md`, `<100` in that file's tier table, and `<200`
> in the workspace `AGENTS.md` — five sites, four numbers, unresolved across three sessions.
> 200 won because it is the figure in the always-on workspace file and the only one MEMORY.md
> was not already violating (it sat at 123). A cap that is continuously exceeded is not a cap.

---

## When to Prune

- Before appending new entry: check if file is >90 lines and prune if needed
- Monthly review: consolidate similar entries
- After major refactoring: ensure entries still apply

---

## What NOT to Save

- Session-specific context (current task details, in-progress work)
- Information that might be incomplete
- Anything that duplicates or contradicts existing CLAUDE.md instructions
- Speculative or unverified conclusions
- Routine workflow steps already documented in rules

---

## Correction Protocol

When user corrects something stated from memory:
1. **Immediately update or remove** the incorrect MEMORY.md entry
2. A correction means the stored memory is wrong
3. Fix at source before continuing
4. Same mistake must not repeat in future conversations

---

## Two-Tier Memory System

**MEMORY.md (committed):**
- Generic workflow patterns
- Cross-project learnings
- Research methodology principles
- Quality standards

**.claude/state/personal-memory.md (gitignored):**
- Machine-specific paths (TEXINPUTS, bibliography)
- Local tool versions and workarounds
- Personal preferences for this machine
- API keys, credentials (encrypted if needed)

---

## Review Cadence

- **After each correction:** Update relevant entry immediately
- **Monthly:** Consolidate and prune (target <150 lines, to leave headroom under the 200 cap)
- **Quarterly:** Verify all entries still apply
- **After major workflow changes:** Audit for obsolete patterns
