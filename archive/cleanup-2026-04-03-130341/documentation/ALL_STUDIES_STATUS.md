# All Simulation Studies Status

**Date:** 2026-03-25
**Status:** Studies 1 & 2 running, Study 3 COMPLETE

---

## Study 3: Classification Accuracy ✓ COMPLETE

**Purpose:** Show traditional methods misclassify transportability; we get it right

**Results:**
- **Our methods:** 71% accuracy, 14% false positive rate
- **Traditional methods:** 38% accuracy, 42% false positive rate
- **Improvement:** +33 percentage points in accuracy
- **FP reduction:** 28 percentage points

**Key Finding:** Traditional methods (PTE, Mediation) reject almost all surrogates (3% sensitivity). Within-study correlation is random (49% accuracy). Our type-level geometric evaluation correctly classifies in 71% of cases.

**Files:**
- Results: `sims/results/classification_results.rds`
- Metrics: `sims/results/classification_metrics.csv`
- Figures: `sims/results/classification_*.pdf`

---

## Study 1: Finite Sample Performance ⏳ RUNNING

**Purpose:** Validate methods work (low bias, good coverage) across realistic settings

**Design:**
- Sample sizes: n ∈ {250, 500, 1000, 2000}
- Lambda values: λ ∈ {0.1, 0.2, 0.3, 0.4}
- Scenarios: 3 (low/mod/high heterogeneity × correlation)
- Replications: 500 per setting
- Total: ~24,000 replications

**Expected runtime:** 2-4 hours

**Monitor:**
```bash
tail -f sims/results/study1_full_run.log
```

**Expected results:**
- Coverage ~95% across all settings
- Bias near zero
- RMSE decreases with n
- Closed-form and sampling give similar estimates

---

## Study 2: Stress Testing ⏳ RUNNING

**Purpose:** Find the limits - where do methods break or weaken?

**Design:**
- Small sample: n ∈ {50, 100, 150}
- Extreme λ: λ ∈ {0.6, 0.7, 0.8, 0.9}
- Discretization: J ∈ {4, 6, 9, 16, 25, 36}
- Weak signal: ρ ∈ {0.05, 0.1, 0.15, 0.2}
- High heterogeneity: CV ∈ {0.6, 0.7, 0.8, 0.9}
- Replications: 500 per stress condition
- Total: ~9,500 replications

**Expected runtime:** 1-2 hours

**Monitor:**
```bash
tail -f sims/results/study2_full_run.log
```

**Expected results:**
- Coverage remains >90% even under stress
- CIs widen appropriately with extreme λ
- Methods robust to discretization (J ≥ 9)
- Weak signal increases uncertainty but maintains validity

---

## Next Steps After Completion

### 1. Generate Tables and Figures
```bash
Rscript sims/scripts/utils/create_tables.R
Rscript sims/scripts/utils/create_figures.R
```

### 2. Update Manuscript Section 5

**New Structure:**
- 5.1: Study Design (3 objectives)
- 5.2: Finite Sample Performance (Study 1)
- 5.3: Robustness and Limits (Study 2)
- 5.4: Classification of Transportability (Study 3) - MAIN STORY
- 5.5: Implications for Practice

**Key message:**
> "When deciding whether to use a surrogate in future studies, traditional methods achieve 38% accuracy with 42% false positive rate. Local geometric evaluation achieves 71% accuracy with 14% false positive rate by directly evaluating correlation between treatment effects across types."

---

## Parallel Processing Fix Applied

All three studies now include package loading inside replication functions:
```r
run_single_replication <- function(...) {
  # Load package (needed for parallel workers)
  suppressPackageStartupMessages({
    library(dplyr, warn.conflicts = FALSE)
    devtools::load_all(here::here("package"), quiet = TRUE)
  })
  # ... rest of function
}
```

This ensures parallel workers have access to package functions and avoid NA estimates.

---

**Last updated:** 2026-03-25 13:30
