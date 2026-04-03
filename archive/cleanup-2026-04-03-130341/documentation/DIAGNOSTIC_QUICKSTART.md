# Quick Start: TV-Ball Minimax Coverage Diagnostics

**Problem:** 64% coverage (should be 95%) in full simulation studies
**Solution:** Run 6 systematic diagnostics to identify root cause

---

## 5-Minute Start

```bash
# 1. Navigate to project
cd /Users/dagniel/RAND/rprojects/surrogates/surrogate-transportability

# 2. Run diagnostics (2-3 hours)
Rscript sims/scripts/diagnostic_coverage_failure.R

# 3. Analyze results (instant)
Rscript sims/scripts/analyze_diagnostics.R
```

That's it! The analysis script will tell you the root cause and what to fix.

---

## What You'll Get

### Terminal Output

```
========================================
DIAGNOSTIC 1: True Types vs Discretized
========================================

Running 100 replications...
  Rep 10 / 100
  ...

RESULTS:
  Discretized: coverage = 0.640 | bias = -0.086 | mean est = 0.093
  True types:  coverage = 0.950 | bias = 0.001 | mean est = 0.178
  Truth mean: 0.179

*** DIAGNOSIS: Discretization mismatch is the ROOT CAUSE ***
```

This repeats for all 6 diagnostics, then the analysis script provides:

```
========================================
ROOT CAUSE IDENTIFICATION
========================================

✗ CRITICAL: DISCRETIZATION MISMATCH
  Evidence: True types give 95.0% coverage, discretized only 64.0%
  → FIX: Improve discretization (increase J, better alignment, or adaptive scheme)

========================================
RECOMMENDED ACTION PLAN
========================================

PRIORITY: Fix critical issues first

1. DISCRETIZATION MISMATCH
    FIX: Improve discretization (increase J, better alignment, or adaptive scheme)
```

---

## The 7 Tests

| # | Test | Hypothesis | If It Fixes → Root Cause |
|---|------|------------|--------------------------|
| 1 | **True types vs Discretized** | Discretization mismatch | Discretization quality |
| 2 | **Individual schemes vs Ensemble** | Ensemble minimum amplifies errors | Aggregation method |
| 3 | **Increasing J** | J=16 too coarse | Number of types |
| 4 | **Closed-form vs Sampling** | Implementation bug | Formula error |
| 5 | **TV-ball vs Wasserstein** | TV-ball specific issue | Geometry constraint |
| 6 | **Point estimate vs CI** | CI too narrow | Bootstrap method |
| 7 | **Observation-level vs Type-level** | J-dimensional fundamentally inadequate | Approximation quality |

**Note:** Test 7 is SLOW (1-2 hours) and optional. Set `RUN_DIAGNOSTIC_7=FALSE` to skip.

---

## Next Steps After Diagnostics

### Based on Results

**If Test 1 (True types) fixes it:**
- Increase J from 16 to [value from Test 3]
- OR use adaptive discretization
- OR switch to observation-level for small n

**If Test 2 (Individual schemes) fixes it:**
- Use best single scheme (likely RF or quantiles)
- OR use median/mean instead of minimum

**If Test 3 (J) fixes it:**
- Update default `J_target` in package

**If Test 4 (Closed-form) finds bug:**
- Debug `estimate_minimax_single_scheme()` lines 64-86
- Check mixture formula: (1-λ)·conc_p0 + λ·min_concordance

---

## Files

### Run These
- `sims/scripts/diagnostic_coverage_failure.R` — Master diagnostic (runs all 6)
- `sims/scripts/analyze_diagnostics.R` — Interprets results, identifies root cause

### Read These
- `DIAGNOSTIC_FRAMEWORK.md` — Complete documentation (this is comprehensive)
- `DIAGNOSTIC_QUICKSTART.md` — This file (quick reference)

### Results Saved To
- `sims/results/coverage_diagnostics.rds` — Full diagnostic results
- `sims/results/diagnostic_*.pdf` — Plots (if generated)

---

## Expected Runtime

- **Total:** 2-3 hours (600 replications)
- **Per diagnostic:** ~20-30 minutes
- **Analysis:** <1 minute

Progress printed to console throughout.

---

## What's Being Tested

### The Problem

From full simulation (24,000 reps):
- Mean estimate: **0.093**
- Mean truth: **0.179**
- Expected: φ*(λ=0.4) = 0.6×0.234 + 0.4×min_j ≈ 0.179

**The (1-λ)P0 term is being lost!** Estimate ≈ min_j when it should be a mixture.

### The Hypotheses

These 6 diagnostics test **why** this is happening:

1. Discretization doesn't match true types?
2. Ensemble minimum selects worst scheme?
3. J=16 too small for TV-ball?
4. Bug in closed-form formula?
5. Bootstrap CIs too narrow?
6. TV-ball geometry issue?

One (or more) will show improvement → that's the root cause.

---

## Troubleshooting

### If script fails

```bash
# Check package is installed
Rscript -e "devtools::load_all('package')"

# Check dependencies
Rscript -e "library(tidyverse); library(MCMCpack)"

# Try running interactively
R
source("sims/scripts/diagnostic_coverage_failure.R")
```

### If results unclear

```bash
# Load and inspect
Rscript -e "
diag <- readRDS('sims/results/coverage_diagnostics.rds')
print(names(diag))
print(diag\$d1_true_types\$coverage_disc)
print(diag\$d1_true_types\$coverage_true)
"
```

### If you need help

1. Read `DIAGNOSTIC_FRAMEWORK.md` (comprehensive)
2. Check console output from diagnostic script
3. Run analysis script again (it's idempotent)

---

## After You Have Results

### Validation Plan

1. **Implement fix** based on root cause (1-2 days)
2. **Test on diagnostic scenario** (100 reps, should hit 93-95%)
3. **Validation subset** (4,800 reps, all settings ≥90%)
4. **Full re-run** Studies 1 & 2 (24k + 10.5k reps, 93-95%)

Timeline: ~1 week from fix to validated solution.

---

**Created:** 2026-03-30
**Status:** Ready to run ✓
**Questions?** See `DIAGNOSTIC_FRAMEWORK.md` for complete details.
