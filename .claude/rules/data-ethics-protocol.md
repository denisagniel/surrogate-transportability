---
paths:
  - "data/**"
  - "scripts/**/*.R"
  - "R/**/*.R"
---

# Data & Ethics Protocol

When adding, changing, or documenting **data** or **scripts that use human or administrative data**, confirm alignment with [meta-spec/RESEARCH_CONSTITUTION.md](../../meta-spec/RESEARCH_CONSTITUTION.md) §4 (Ethics and Responsibility) before commit.

## Checklist (before commit)

- [ ] **Data provenance:** Source, date, and processing steps are documented (README, codebook, or project spec).
- [ ] **Consent / IRB:** Where relevant, consent and IRB/ethics approval are noted; no identifiable data committed without approval.
- [ ] **Equity:** If the method or data affects populations, equity implications have been considered (constitution §4).

If any item is not applicable, document why (e.g. "synthetic data only") in README or MEMORY.md.

## Use

- Triggered when working under `data/` or on R scripts in `scripts/` or `R/` that load or process human/administrative data.
- For grant or applied projects, grant-reviewer and domain-reviewer also check evidence and limitations; this rule ensures data/ethics are checked at commit time for data-heavy work.
