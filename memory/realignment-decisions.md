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

Additional decisions (2026-07-08, after Phase 1.5):
- **Legacy DGP family: DELETE.** Confirmed §9 Q1 — promote `generate_dgp_data` into `R/`, delete `data_generators.R` (+ `_corrected`, `generate_future_study` family) despite 28 legacy references (none on the canonical path).
- **Cluster jobs: regenerate with the `setup-cluster-simulations` skill** from `~/RAND/tools/agent-assisted-research-meta` (template-driven O2 infra, canonical `simulations/<study>/` layout, run-id lifecycle, scratch/home discipline). This supersedes the ad-hoc `cluster/` + `sims/` directories. New Phase 2.5. HMS id `dma12`, scratch `/n/scratch/users/d/dma12/`.

- **Merge posture (2026-07-08):** merge `canonical-realignment` → `main` automatically at the end of Phase 6 **if** the final fidelity pass + quality gate pass (≥90). Otherwise present findings and hold.

Master plan: `quality_reports/plans/2026-07-08_canonical-realignment-master-plan.md`.
