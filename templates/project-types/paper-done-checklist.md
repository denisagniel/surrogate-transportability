# Paper Done Checklist: [Paper Title]

**Date:** [YYYY-MM-DD]
**Status:** DRAFT | READY
**Purpose:** Confirm the project meets the definition of “finished” (constitution §12) before treating it as ready for preprint/submission. Align with [meta-spec/RESEARCH_CONSTITUTION.md](../../meta-spec/RESEARCH_CONSTITUTION.md).

---

## Common (all papers)

- [ ] Scientific claim sharply stated
- [ ] (If methods) Operating regime understood; failure modes documented
- [ ] (If software) Software reliable; another careful researcher could apply it correctly
- [ ] Analysis code, R package (if any), and paper in agreement and publication-ready
- [ ] Reproducibility: can be reproduced easily (replication package ready or clearly scoped)

## Applied / medical / partial authorship

- [ ] Takeaway clear for intended audience
- [ ] Limitations stated
- [ ] Scope of responsibility respected; claims scoped to contribution

## Paper–simulation–package alignment

*When the project has simulation code and/or an R package, complete the three-way fidelity checks.*

- [ ] Simulation code matches paper (theory): same estimand, assumptions, design; every paper design choice has matching code
- [ ] Simulation DGPs and results reported accurately in paper: reported regimes/numbers from code; no silent mismatches
- [ ] Package ≥ paper: package implements at least what the paper describes; never less
- [ ] Cross-check complete: paper, simulation code, and package used to verify each other

**Full rule:** [.claude/rules/code-paper-package-alignment.md](../../.claude/rules/code-paper-package-alignment.md)

## Next step

If this project will post a preprint (see [preprint protocol](../../.claude/rules/preprint-protocol.md) for scope: methods yes; applied often not; partial responsibility no), use the **preprint** checklist and protocol for posting:

- [Preprint checklist](preprint-checklist.md)
- [Preprint protocol](../../.claude/rules/preprint-protocol.md)

---

## Notes

[Project-specific notes.]
