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

A complete R project implementing surrogate inference via random probability distributions for evaluating treatment effects in future studies. The innovation approach models future studies as mixtures Q = (1-λ)P₀ + λP̃ to assess surrogate transportability.

**Current Stage:** Methods paper revised for journal submission (Feb 2026)

**Key Components:**
- **R Package:** surrogateTransportability v0.1.0 (MIT License) - 7 main files, 2,076 lines
- **Simulations:** R6-based simulation environment with 6 scenario scripts and YAML configuration
- **Methods Paper:** methods/main.tex (~221 lines, recently revised)
- **Critical Functionals:** Correlation, probability, conditional mean for surrogate evaluation

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
├── package/                  # R package: surrogateTransportability v0.1.0
│   ├── R/                    # Package functions (data generators, functionals, inference)
│   ├── tests/                # Unit tests
│   └── DESCRIPTION           # Package metadata
├── sims/                     # Simulation environment
│   ├── classes/              # R6 simulation classes
│   ├── scripts/              # Scenario scripts (01-06)
│   ├── config/               # YAML configuration (scenarios.yaml)
│   └── results/              # Simulation outputs (.rds, .csv, plots)
├── methods/                  # LaTeX manuscript
│   ├── main.tex              # Primary manuscript (~221 lines)
│   ├── common-defs.tex       # Shared definitions
│   └── refs.bib              # Bibliography
├── refs/                     # Reference papers
├── latex-dotfiles/           # Shared LaTeX style
├── templates/                # Session logs, quality reports, requirements
├── session_notes/            # Dated session summaries (YYYY-MM-DD.md)
├── quality_reports/          # Plans, session logs, merge reports (created as needed)
└── explorations/             # Research sandbox (see rules)
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

- **Stage:** Methods paper revised for journal submission (February 2026)
- **Package:** surrogateTransportability v0.1.0 with 6 core functions and unit tests
- **Simulations:** 6 scenario scripts completed; results in sims/results/
- **Paper:** methods/main.tex recently revised; uses shared latex-dotfiles style
- **Next Steps:** Address referee comments; extend simulation scenarios; prepare preprint

---

## Critical Files

- [package/R/posterior_inference.R](package/R/posterior_inference.R) - Main inference function with nested Bayesian bootstrap
- [package/R/generate_future_study.R](package/R/generate_future_study.R) - Innovation approach: Q = (1-λ)P₀ + λP̃
- [package/R/surrogate_functionals.R](package/R/surrogate_functionals.R) - Correlation, probability, conditional mean
- [sims/classes/SurrogateSimulation.R](sims/classes/SurrogateSimulation.R) - R6 simulation framework
- [methods/main.tex](methods/main.tex) - Methods manuscript (~221 lines)
- [sims/config/scenarios.yaml](sims/config/scenarios.yaml) - Simulation parameter definitions

---

## Explorations and Session Notes

- **Explorations:** Use `explorations/` for experimental work; see `.claude/rules/exploration-folder-protocol.md` and `.claude/rules/exploration-fast-track.md`.
- **Session notes:** Dated markdown files in `session_notes/` (YYYY-MM-DD.md format); updated with session logs; feed daily notes at `$AGENT_ASSISTED_RESEARCH_META_NOTES`.
