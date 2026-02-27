---
paths:
  - "Slides/**/*.tex"
  - "slides/**/*.tex"
  - "presentation/**/*.tex"
  - "latex/**/*.tex"
  - "proposal/**/*.tex"
  - "grants/**/*.tex"
  - "**/main.tex"
  - "Quarto/**/*.qmd"
  - "scripts/**/*.R"
---

# Quality Gates & Scoring Rubrics

## Thresholds

- **80/100 = Commit** -- good enough to save
- **90/100 = PR** -- ready for deployment
- **95/100 = Excellence** -- aspirational

## LaTeX Manuscripts (non-Beamer .tex)

| Severity | Issue | Deduction |
|----------|-------|-----------|
| Critical | XeLaTeX/BibTeX compilation failure | -100 |
| Critical | Undefined citation or reference | -15 |
| Critical | Overfull hbox > 10pt | -10 |
| Major | Broken cross-reference | -5 |
| Major | Inconsistent notation vs. project spec | -5 |
| Minor | Long lines (>100 chars) in prose | -1 (EXCEPT documented formulas) |

## LaTeX Proposals (grants)

| Severity | Issue | Deduction |
|----------|-------|-----------|
| Critical | XeLaTeX/BibTeX compilation failure | -100 |
| Critical | Undefined citation or reference | -15 |
| Critical | Overfull hbox > 10pt | -10 |
| Major | Broken cross-reference | -5 |
| Major | Missing required section (Aims, Significance, Approach, or funder-required equivalent) | -10 |
| Major | Review criteria not addressed (no mapping to funder criteria) | -5 |
| Major | Inconsistent notation vs. project spec | -5 |
| Minor | Long lines (>100 chars) in prose | -1 (EXCEPT documented formulas) |

## Quarto Slides (.qmd)

| Severity | Issue | Deduction |
|----------|-------|-----------|
| Critical | Compilation failure | -100 |
| Critical | Equation overflow | -20 |
| Critical | Broken citation | -15 |
| Critical | Typo in equation | -10 |
| Major | Text overflow | -5 |
| Major | TikZ label overlap | -5 |
| Major | Notation inconsistency | -3 |
| Minor | Font size reduction | -1 per slide |
| Minor | Long lines (>100 chars) | -1 (EXCEPT documented math formulas) |

## Quarto Reports / Manuscripts (.qmd non-slides)

| Severity | Issue | Deduction |
|----------|-------|-----------|
| Critical | Render failure | -100 |
| Critical | Broken citation or reference | -15 |
| Critical | Typo in equation or key result | -10 |
| Major | Text overflow or broken layout | -5 |
| Major | Notation inconsistency | -3 |
| Minor | Long lines (>100 chars) in prose | -1 (EXCEPT documented formulas) |

## R Scripts (.R)

| Severity | Issue | Deduction |
|----------|-------|-----------|
| Critical | Syntax errors | -100 |
| Critical | Domain-specific bugs | -30 |
| Critical | Hardcoded absolute paths | -20 |
| Major | Missing set.seed() | -10 |
| Major | Missing figure generation | -5 |

## Beamer Slides (.tex)

| Severity | Issue | Deduction |
|----------|-------|-----------|
| Critical | XeLaTeX compilation failure | -100 |
| Critical | Undefined citation | -15 |
| Critical | Overfull hbox > 10pt | -10 |

## Enforcement

- **Score < 80:** Block commit. List blocking issues.
- **Score < 90:** Allow commit, warn. List recommendations.
- User can override with justification.

## Quality Reports

Generated **only at merge time**. Use `templates/quality-report.md` for format.
Save to `quality_reports/merges/YYYY-MM-DD_[branch-name].md`.

## Tolerance Thresholds (Research)

<!-- Default values for replication and simulation checks; customize per project if needed. -->

| Quantity | Tolerance | Rationale |
|----------|-----------|-----------|
| Point estimates | 1e-6 | Numerical precision; double precision relative tolerance |
| Standard errors | 1e-4 | MC variability with typical B (e.g. 1000–10000) |
| Coverage rates | ±0.01 | MC sampling; e.g. nominal 0.95 → accept 0.94–0.96 |
| p-values (replication) | 1e-4 | Reporting precision; MC when p-values come from simulations |

**Override:** Projects may set stricter or looser values in project spec or MEMORY.md (e.g. 1e-8 for point estimates, ±0.005 for coverage). Use these when comparing replication output or simulation summaries.
