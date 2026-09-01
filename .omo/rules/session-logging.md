---
paths:
  - "quality_reports/**"
---

<!-- GENERATED from .claude/rules/session-logging.md by scripts/generate-omo-rules.sh — DO NOT EDIT -->

# Session Logging — RETIRED 2026-09-01

**This rule is retired. The single session record is `session_notes/YYYY-MM-DD.md`.**
See `.claude/rules/session-notes.md`.

Do not create or append to `quality_reports/session_logs/`. Existing files there are
**historical** and frozen; leave them alone.

## Why

`quality_reports/session_logs/` was a second session record maintained in parallel with
`session_notes/`, mandated at the *same three triggers*. Measured across the workspace on
2026-09-01:

| Finding | |
|---|---|
| Projects with the two streams in sync | **1 of ~15** |
| Projects with session notes but **zero** logs | 5 |
| Effective compliance with the dual-write mandate | **~10-15%** |
| `merges/` quality reports, mandated at merge time | **0 files, ever** |

The log carried almost nothing of its own: Design Decisions duplicated `plans/`, Learnings
duplicated `MEMORY.md`, Changes Made duplicated `git log`, Verification duplicated the quality
gates. What remained was machine-derivable. Artifacts nothing reads decay to zero regardless
of who is writing them, so the duplicate was removed rather than re-mandated.

It was also **actively corrupting itself**. The `PreCompact` hook appended a compaction marker
to whichever log file had the newest mtime - never the current session's - and the `Stop` hook
independently pointed the agent at that same wrong file. The two formed a closed feedback loop:
**393 stray markers across 124 log files in 14 projects**, one file absorbing 26 markers from
26 unrelated sessions. Both hooks were removed 2026-09-01.

## What replaced what

| Was in the session log | Now lives in |
|---|---|
| Objective, summary, incremental entries | `session_notes/YYYY-MM-DD.md` |
| Design decisions | `quality_reports/plans/` (pre-approval) + notes |
| Learnings | `MEMORY.md`, via `/learn` only - see `.claude/rules/memory-curation.md` |
| Changes made (file / change / reason) | `git log`, `git diff` |
| Verification results | quality gates - see `.claude/rules/quality-gates.md` |
| Per-file quality-score column | **nothing. Deliberately dropped** - it had no reader |

## This file is a stub on purpose

The path is kept rather than deleted because roughly 90 framework and project files reference
`session-logging`. Deleting it would trade one broken mechanism for ninety broken links. The
`paths:` frontmatter is retained so that an agent touching `quality_reports/` is told the logs
are retired instead of silently reviving them.

Full diagnosis and remediation plan:
`missing-data-did/quality_reports/plans/2026-09-01_session-logging-architecture-remediation.md`
