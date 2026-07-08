# CLAUDE.MD -- Surrogate Transportability

<!-- Customized for surrogate-transportability. Research constitution and meta-spec are authoritative.
     Keep this file under ~150 lines — the agent loads it every session. -->

**Project:** surrogate-transportability
**Branch:** main
**Type:** Methods / Causal Inference Paper

---

## Authority

- **Read before substantive work:** [meta-spec/RESEARCH_CONSTITUTION.md](meta-spec/RESEARCH_CONSTITUTION.md). All outputs (methods, claims, code, writing) must align with the research constitution. If a prompt conflicts with these, follow the constitution and surface the conflict.
- **I/you convention:** In agent-facing guidance in this repo, "I"/"my" = agent, "you"/"your" = human unless the sentence clearly instructs the agent (e.g. "You are a...").

---

## Project Overview

A complete R project for evaluating surrogate transportability from a single study. The canonical method models future studies as random measures drawn uniformly from a **total-variation ball** around the observed study, and estimates the **correlation of treatment effects** on surrogate and outcome across those studies via hit-and-run MCMC + importance weighting / cross-fitted AIPW, with influence-function inference. (The earlier mixture framing Q = (1-λ)P₀ + λP̃ is abandoned.)

**Current Stage:** Canonical realignment in progress (July 2026); aligning package, manuscript, and simulations to the May 2026 presentation (`inst/presentation/slides.qmd`, the source of truth).

**Key Components:**
- **R Package:** surrogateTransportability v0.4.0 (MIT License) - 8 R files, 13 exports (post-realignment)
- **Simulations:** O2 cluster study at `simulations/canonical-validation/` (4 DGPs, fixed estimator)
- **Methods Paper:** `inst/paper/main.tex` (realigned) + `proof_asymptotic_normality.tex`
- **Primary functional:** correlation of treatment effects across future studies

---

## Core Principles

- **Plan first** — enter plan mode before non-trivial tasks; save plans to `quality_reports/plans/` when that folder exists
- **Verify after** — compile/render and confirm output at the end of every task
- **Quality gates** — nothing ships below 80/100 (commit); 90 PR; 95 excellence
- **[LEARN] tags** — when corrected, save `[LEARN:category] wrong → right` to MEMORY.md

---

## Folder Structure

```
surrogate-transportability/
├── CLAUDE.md                 # This file
├── MEMORY.md                 # Session-persistent learning
├── README.md                 # Project overview and quick start
├── .claude/                  # Rules, skills, agents, hooks
├── meta-spec/                # Research constitution, background (authoritative)
├── DESCRIPTION               # Package metadata
├── NAMESPACE                 # Package exports
├── R/                        # Package functions (data generators, functionals, inference)
├── tests/                    # Unit tests
├── man/                      # Generated documentation (roxygen2)
├── examples/                 # Package examples
├── validation/               # Validation scripts
├── inst/
│   ├── paper/                # LaTeX manuscript + proof + IF derivation
│   │   ├── main.tex          # Primary manuscript (realigned)
│   │   ├── proof_asymptotic_normality.tex
│   │   ├── derivation_influence_functions.md
│   │   ├── common-defs.tex   # Shared definitions
│   │   └── refs.bib          # Bibliography
│   └── presentation/         # CANONICAL slides (slides.qmd, source of truth)
├── simulations/              # O2 cluster studies (setup-cluster-simulations layout)
│   └── canonical-validation/ # 4-DGP coverage study (fixed estimator)
├── refs/                     # Reference papers
├── latex-dotfiles/           # Shared LaTeX style
├── templates/                # Session logs, quality reports, requirements
├── session_notes/            # Dated session summaries (YYYY-MM-DD.md)
├── quality_reports/          # Plans, session logs, merge reports (created as needed)
├── explorations/             # Research sandbox (see rules)
└── archive/                  # Archived clutter files (cleanup-YYYY-MM-DD)
```

**Session notes:** Updated with session logs (post-plan, incremental, end-of-session); feed daily notes at `$AGENT_ASSISTED_RESEARCH_META_NOTES`. See [meta-spec/META_PROJECT_NOTES.md](meta-spec/META_PROJECT_NOTES.md).

---

## Tools and Conventions

- **R:** Primary language for analysis and reproducibility. Follow `.claude/rules/r-code-conventions.md`. Modern R patterns: 7 custom skills (writing-tidyverse-r, metaprogramming-rlang, optimizing-r, designing-oop-r, customizing-vectors-r, developing-packages-r, techdebt-r). R package development: 4 Posit skills (testing-r-packages, cli-r, critical-code-reviewer, quarto-authoring). See `.claude/skills/README.md`.
- **Package Development:** Use devtools workflow; document with roxygen2; test with testthat
- **Simulations:** R6 classes with YAML configuration; results saved as .rds for reproducibility
- **Reproducibility:** Required. If it cannot be reproduced easily, it is not finished (constitution).
- **LaTeX:** Shared style via latex-dotfiles/. Compile via `/compile-latex`. Use LATEX_DOTFILES environment variable.
- **RAND Style:** Figures use randplot conventions (see r-code-conventions.md)

---

## Quality Thresholds

| Score | Gate       | Meaning                |
|-------|------------|------------------------|
| 80    | Commit     | Good enough to save    |
| 90    | PR         | Ready for deployment   |
| 95    | Excellence | Aspirational           |

**Exception - Exploration Mode:**
- Threshold: 60/100 for experimental work in `explorations/`
- No planning needed; code immediately
- Decision point: Graduate to production (upgrade to 80/100) or archive
- See `.claude/rules/exploration-fast-track.md`

---

## Skills Quick Reference (Research-Focused)

| Command                  | What It Does                        |
|--------------------------|-------------------------------------|
| `/lit-review [topic]`    | Literature search + synthesis       |
| `/research-ideation [topic]` | Research questions + strategies |
| `/interview-me [topic]`  | Interactive research interview      |
| `/review-paper [file]`   | Manuscript review                   |
| `/data-analysis [dataset]` | End-to-end R analysis            |
| `/simulations [estimator or setting]` | Design and run R simulation study (stress-testing, DGP, review) |
| `/review-r [file]`       | R code quality review               |
| `/devils-advocate`       | Challenge design before committing  |
| `/proofread [file]`      | Grammar/typo/consistency            |
| `/compile-latex [target]` | Compile LaTeX document (e.g., main) |
| `/commit [msg]`          | Stage, commit, PR, merge            |

**Additional commands:** `/presentation-review [file]` for slides; `/validate-bib` for bibliography checks.

**Verification:** Invoke the verifier agent before commit or when creating PRs.

---

## Agents and Skills in Use

**In use:** domain-reviewer (papers, code), verifier (papers, code), r-reviewer (RAND style), proofreader, structure-reviewer (manuscripts). Optionally tikz-reviewer (manuscript figures).

**Skills:** `/review-paper` for full manuscript review; `/review-r` for R code; `/simulations` for simulation studies; `/compile-latex` for methods paper.

---

## Project Type

**Methods / Causal Inference** (see [templates/project-types/methods-paper-requirements.md](templates/project-types/methods-paper-requirements.md))

- **Target:** Top statistics/biostatistics journals
- **Emphasis:** Identification, theory, stress-testing, software (R package)
- **Preprint Policy:** Methods papers → preprints before or alongside submission
- **Requirements:** Clear theory, comprehensive simulations, working implementation

---

## Current Project State

- **Stage:** Canonical realignment (July 2026) — aligning everything to the May 2026 slides.
- **Package:** surrogateTransportability v0.4.0 — 8 R files, 13 exports, tests passing.
- **Simulations:** O2 study `simulations/canonical-validation/` (4 DGPs, fixed estimator); awaiting cluster re-validation.
- **Paper:** `inst/paper/main.tex` realigned (compiles; Table 2 + figures pending cluster output).
- **Next Steps:** run cluster re-validation; fill Table 2/figures; preprint.

---

## Critical Files

- [R/tv_ball_correlation_IF_adaptive.R](R/tv_ball_correlation_IF_adaptive.R) - THE estimator (hit-and-run + IF inference + AIPW)
- [R/tv_ball_sampling.R](R/tv_ball_sampling.R) - uniform hit-and-run sampler on the TV ball
- [R/dgp_canonical.R](R/dgp_canonical.R) - `generate_dgp_data` + `canonical_dgp_params` (the 4 canonical DGPs)
- [R/traditional_methods.R](R/traditional_methods.R) - PTE / mediation / within-study correlation (comparisons)
- [inst/paper/main.tex](inst/paper/main.tex) - Methods manuscript (realigned)
- [inst/paper/derivation_influence_functions.md](inst/paper/derivation_influence_functions.md) - IF derivation (code + proof reference)
- [inst/presentation/slides.qmd](inst/presentation/slides.qmd) - CANONICAL source of truth

---

## Explorations and Session Notes

- **Explorations:** Use `explorations/` for experimental work; see `.claude/rules/exploration-folder-protocol.md` and `.claude/rules/exploration-fast-track.md`.
- **Session notes:** Dated markdown files in `session_notes/` (YYYY-MM-DD.md format); updated with session logs; feed daily notes at `$AGENT_ASSISTED_RESEARCH_META_NOTES`.
