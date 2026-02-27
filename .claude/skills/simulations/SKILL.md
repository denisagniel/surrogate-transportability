---
name: simulations
description: Design and run R simulation studies (Monte Carlo, DGPs) with stress-testing and reproducibility. Use when the user asks for "simulation", "Monte Carlo", "run a DGP", "simulation study", or "add simulations for this estimator".
argument-hint: "[estimator or method name] or [brief DGP/setting description]"
disable-model-invocation: true
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Task"]
---

# Simulations Workflow

Design and implement a simulation study in R that satisfies the research constitution (stress-testing, adversarial regimes, no impress-only sims) and produces code that r-reviewer can check without structural changes.

**Input:** `$ARGUMENTS` — an estimator or method name, or a brief DGP/setting description (e.g. "OLS vs IV under endogeneity", "add simulations for the estimator in Section 3").

**Authority:** [meta-spec/RESEARCH_CONSTITUTION.md](../../meta-spec/RESEARCH_CONSTITUTION.md) — simulation invariants (Section 9) and anti-goals (Section 11). When generating code, analysis, or simulations, follow this spec as highest-priority guidance. When the simulation supports a paper, ensure alignment per [.claude/rules/code-paper-package-alignment.md](../../.claude/rules/code-paper-package-alignment.md).

---

## Constraints

- **Follow R code conventions** in `.claude/rules/r-code-conventions.md`
- **Save all scripts** to `scripts/R/` with descriptive names; outputs in `output/` (or project convention)
- **One `set.seed()`** at top only; never inside loops or functions
- **No per-iteration printing** inside simulation loops; use `message()` sparingly (one per major section maximum)
- **Numbered sections** matching r-reviewer: **0. Setup, 1. Data/DGP, 2. Estimation, 3. Run, 4. Figures, 5. Export**
- If using **parallel**: register and unregister backend; document in comments
- **Run r-reviewer** on the generated script before presenting results; address Critical/High issues before done

---

## Workflow Phases

### Phase 1: Design (constitution-aligned)

1. Read `.claude/rules/r-code-conventions.md` and meta-spec/RESEARCH_CONSTITUTION.md (simulation invariants, anti-goals).
2. Clarify estimand and method being evaluated.
3. Plan regimes: **at least one where the method should struggle** (stress-testing); avoid only "favorable" parameter settings.
4. If appropriate: separate nuisance vs target performance; consider one adversarial/misspecification regime (per templates/project-types/methods-paper-requirements.md).
5. Decide metrics: bias, MSE, coverage, CI width, etc., and number of replications.

### Phase 2: Setup and DGP (Sections 0 and 1)

1. Create R script with header block: title, author, purpose, inputs (none or config), outputs (RDS/parquet, figures).
2. Load packages at top via `library()` (never `require()`); `set.seed(.)` once; `fs::dir_create()` for output directories.
3. Implement DGP as function(s): verb-noun naming (e.g. `generate_dgp_linear()`), roxygen-style docs, arguments for key parameters (sample size, noise level, etc.).
4. No magic numbers inside DGP; prefer tibble return; named list if non-tabular.

### Phase 3: Estimation and run (Sections 2 and 3)

1. Estimation: function(s) that take data from DGP and return point estimate and, if applicable, SE/CI (no estimator without uncertainty quantification unless justified).
2. Single replication function: generate data → run estimator → return one tidy row (e.g. bias, MSE, coverage, CI width).
3. Main loop over regimes and/or parameters; aggregate into one results tibble. No `cat()`/`print()` inside the loop.
4. Check for NA/NaN/Inf; count and report failed replications.

### Phase 4: Figures and export (Sections 4 and 5)

1. Summary tables and plots (e.g. performance by regime, by n).
2. ggplot2 with project theme; `bg = "transparent"` for Beamer; explicit `ggsave(width = ..., height = ...)`.
3. `readr::write_rds()` for full results and summary tables (or `arrow::write_parquet()` for large tabular results); use `file.path()` or `fs::path()` for paths.
4. For long-running loops: prototype first, estimate run time, consider parallelization (e.g. furrr), and plan for summary updates and/or progress bars (see `.claude/rules/r-code-conventions.md`).

### Phase 5: Review

1. Delegate to the r-reviewer agent: "Review the script at scripts/R/[script_name].R"
2. Address any Critical or High issues from the review before considering the skill run complete.

---

## Script Structure

Use this section layout so generated scripts match r-reviewer expectations:

```r
# ============================================================
# [Title: e.g. "Simulation: OLS vs IV in presence of endogeneity"]
# Purpose: [One line]
# Inputs: none (or config file)
# Outputs: [RDS/parquet, figures]
# ============================================================

# 0. Setup ----
# 1. Data/DGP ----
# 2. Estimation ----
# 3. Run ----
# 4. Figures ----
# 5. Export ----
```

---

## Important / anti-goals

- **Reproduce, don't guess.** If the user specifies a DGP or estimator from a paper, implement that.
- **Stress-test.** Include at least one regime where the method is expected to perform poorly.
- **No impress-only sims.** Avoid parameter sets that only make the proposed method look good (constitution Section 11).
- **Paths.** All paths relative to repository root; no hardcoded absolute paths.
- **Parallel.** If using parallel, register and unregister backend; document in comments.

---

## Examples

**Example 1: "Run a Monte Carlo for OLS under endogeneity"**  
Design: OLS biased vs IV; DGP with instrument strength and sample size; one replication function returning bias/MSE/coverage; loop over regimes; summary table and plot; readr::write_rds (or parquet for large tabular); run r-reviewer on the script.

**Example 2: "Add a simulation for the estimator in Section 3"**  
Extract DGP from paper or user; implement matching DGP; same pipeline (replication function, loop, tables/figures, save, review).

---

## Troubleshooting

**All replications fail or many NA/NaN:** Check DGP (numerics, support), estimator (errors, edge cases). Add explicit NA/failure checks and report failed replication count in output.

**Results don't match paper:** Verify DGP and estimand match the paper (e.g. ATT vs ATE); check seed and that only one `set.seed()` is used at top.
