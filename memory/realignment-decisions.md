---
name: realignment-decisions
description: User decisions governing the canonical-realignment effort (deletion posture, audit scope)
metadata:
  type: project
---

Decisions made 2026-07-08 for the canonical-realignment effort (see [[canonical-method-spec]]):

- **Deprecation posture: DELETE off-canonical code** (git preserves history). This explicitly **overrides** the older May-1 2026 planning docs (`DEPRECATIONS.md`, `DEPRECATION_EXECUTIVE_SUMMARY.md`) which recommended "keep but flag as experimental." Those May-1 docs are pre-canonical (predate the final May 12 slides) and superseded.
- **Correctness audit scope: canonical pipeline only** — do not deep-audit code slated for deletion.
- **Sequencing:** correctness audit (read-only) happens BEFORE any deletion, so we don't remove a live dependency of the canonical path.

Master plan: `quality_reports/plans/2026-07-08_canonical-realignment-master-plan.md`.
