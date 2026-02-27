---
paths:
  - "latex/**/*.tex"
  - "slides/**/*.qmd"
  - "presentation/**/*.qmd"
  - "**/main.tex"
---

# Preprint Protocol (arXiv)

**Methods / causal inference** papers are posted as preprints (before or alongside journal submission). **Applied papers** (applied stats, medical/subject) probably will not get preprints; **partial-responsibility** papers (e.g. methods + results only) definitely will not.

**When this protocol applies:** Use this protocol when the project will post a preprint—i.e. when it’s a methods paper, or an applied full paper by explicit decision; never for partial responsibility. Ensure the project satisfies the “paper done” criteria (constitution §12) via [templates/project-types/paper-done-checklist.md](../../templates/project-types/paper-done-checklist.md) before completing the steps below. Use this checklist when preparing a paper for preprint.

This protocol is tuned for **arXiv**. For other servers (e.g. bioRxiv, SSRN, OSF), adapt these steps.

## Before posting

- [ ] **Manuscript:** Compiles cleanly (xelatex + bibtex); no undefined refs/citations; quality gate ≥ 80. See [verification-protocol.md](verification-protocol.md) and [quality-gates.md](quality-gates.md). arXiv typically accepts PDF from pdflatex (and other engines); ensure the project build produces a single PDF or uploadable source bundle for straightforward submission.
- [ ] **Replication:** Replication package is ready (code, data or access instructions, README). Reproducibility is infrastructure (constitution).
- [ ] **Claims:** Wording matches strength of evidence; limitations stated (constitution §8). No causal language without assumptions nearby.
- [ ] **Authors:** All authors have approved the preprint and chosen server/license.
- [ ] **arXiv category:** Choose a primary category (e.g. stat.ME, stat.TH, cs.LG, stat.AP). See [arXiv category taxonomy](https://arxiv.org/category_taxonomy) for stats/methods.
- [ ] **Endorsement:** If any author is a first-time arXiv submitter, obtain endorsement (institutional email + prior arXiv paper in same domain, or personal endorsement from an established arXiv author in the field). See [arXiv endorsement](https://info.arxiv.org/help/endorsement.html).
- [ ] **License:** Choose display license (e.g. CC BY 4.0). Document in README or project spec.

## After posting

- [ ] **Link:** Add preprint URL (and arXiv identifier, e.g. arXiv:YYMM.NNNNN) to README, project spec, or MEMORY.md so it is easy to find.
- [ ] **Citation:** If the project has a preferred citation format for the preprint, document it (e.g. author, title, arXiv:YYMM.NNNNN).

## Template

Use [templates/project-types/preprint-checklist.md](../../templates/project-types/preprint-checklist.md) for project-specific preprint tracking.
