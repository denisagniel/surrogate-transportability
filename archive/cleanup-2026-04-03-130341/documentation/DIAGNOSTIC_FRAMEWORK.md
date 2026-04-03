# TV-Ball Minimax Coverage Diagnostic Framework

**Status:** Ready to run
**Created:** 2026-03-30
**Purpose:** Systematic diagnosis of 64% coverage failure in TV-ball minimax method

---

## Executive Summary

Full simulation studies (24,000 + 10,500 replications) revealed **catastrophic coverage failure**:
- **Overall coverage: 64%** (should be 95%)
- **Worst setting: 29% coverage** (n=250, λ=0.4, low_het_high_cor)
- **Pattern: Systematic underestimation** (71% of failures have truth above CI)

This diagnostic framework runs **6 systematic tests** to identify the root cause through evidence, not guessing.

---

## What We're Testing

### The Crisis

From `examine_failed_cases.R` on worst setting:
- Mean estimate: **0.093**
- Mean truth: **0.179** (true minimax under true parameters)
- Mean P0 concordance: **0.234**

**Expected by closed-form formula:**
```
φ*(λ=0.4) = (1-0.4)×0.234 + 0.4×min_j
          = 0.6×0.234 + 0.4×min_j
          ≈ 0.179
```

Solving: `min_j ≈ 0.098`

**But estimate ≈ 0.093 ≈ min_j** — the (1-λ)P0 term is being lost!

### Hypotheses Being Tested

1. **Discretization mismatch:** RF/kmeans/quantiles bins ≠ true DGP types → estimated min_j ≠ true min_j
2. **Ensemble minimum amplification:** Taking min across schemes selects most error-prone
3. **J=16 too coarse:** Need more types for adequate exploration
4. **Closed-form bug:** Implementation doesn't compute (1-λ)P0 + λ·min correctly
5. **Bootstrap CI issue:** Point estimate fine, CIs too narrow
6. **TV-ball specific:** Wasserstein unaffected (different issue)

---

## The 6 Diagnostics

### Diagnostic 1: True Types vs Discretized Types

**Hypothesis:** Discretization mismatch causes min_j(τ̂_j^s·τ̂_j^y) ≠ min_j(τ_j^s·τ_j^y)

**Method:**
- Generate data with **known true type assignments** from DGP
- Run minimax with:
  - A. Discretization (RF/quantiles/kmeans) — current approach
  - B. True types (oracle, no discretization)

**If true types give 95% coverage:** Discretization mismatch is the problem
**If true types still give 64% coverage:** Discretization is NOT the issue

**Key insight:** We can test this because simulation knows the true types!

---

### Diagnostic 2: Individual Schemes vs Ensemble

**Hypothesis:** Taking minimum across schemes amplifies errors

**Method:**
- Run minimax with:
  - A. RF only
  - B. Quantiles only
  - C. K-means only
  - D. Ensemble (min over all three) — current

**If individual schemes give 90%+ coverage:** Ensemble minimum is the problem
**If all schemes give 64% coverage:** Ensemble is NOT the issue

---

### Diagnostic 3: Increasing J

**Hypothesis:** J=16 is too coarse; need more types for TV-ball exploration

**Method:**
- Run minimax with J ∈ {16, 32, 64}
- Use quantiles scheme for consistency
- Plot: coverage vs J

**If coverage improves with J:** J=16 is too coarse
**If coverage flat across J:** Number of types is NOT the issue

---

### Diagnostic 4: Closed-Form vs Sampling

**Hypothesis:** Bug in closed-form implementation

**Method:**
For concordance functional:
- A. **Closed-form:** φ*(λ) = (1-λ)·conc_p0 + λ·min_j (instant)
- B. **Sampling:** Generate 5,000 Dirichlet innovations, compute via reweighting (brute force)
- C. **Theoretical:** Compute from true DGP parameters

Compare point estimates (use true types to isolate formula issue).

**If closed-form biased but sampling unbiased:** Implementation bug
**If both match:** Formula is correct

---

### Diagnostic 5: TV-Ball vs Wasserstein

**Hypothesis:** Issue is specific to TV-ball geometry; Wasserstein unaffected

**Method:**
- Run same scenario with:
  - A. TV-ball minimax (current, 64% coverage)
  - B. Wasserstein minimax (unknown coverage)

**If Wasserstein gives 95%:** TV-ball specific issue
**If Wasserstein also gives 64%:** Broader problem with minimax approach

**Note:** Wasserstein uses continuous geometry via cost matrix C[i,j] = ||centroid_i - centroid_j||²,
which may be less sensitive to discretization than TV-ball's discrete type assumption.

---

### Diagnostic 6: Bootstrap CI Construction

**Hypothesis:** Point estimate is fine; CI construction is wrong

**Method:**
- Check if truth is consistently within ±1.96 SE of estimate
- Compute Z-scores: (estimate - truth) / SE
- Expected if well-calibrated: mean Z ≈ 0, SD Z ≈ 1

**From existing results:**
- Mean estimate: 0.093
- Mean truth: 0.179
- Difference: 0.086 (almost 2× the estimate!)

→ **This is NOT a CI width issue, it's a bias issue**

But we test it systematically to confirm.

---

## Running the Diagnostics

### Quick Start

```bash
# From project root
cd /Users/dagniel/RAND/rprojects/surrogates/surrogate-transportability

# Run all 6 diagnostics (2-3 hours)
Rscript sims/scripts/diagnostic_coverage_failure.R

# Analyze results
Rscript sims/scripts/analyze_diagnostics.R
```

### What Happens

**Phase 1:** Run 6 diagnostics
- 100 replications per diagnostic (600 total)
- Each diagnostic tests one hypothesis
- Progress printed to console
- Results saved to `sims/results/coverage_diagnostics.rds`

**Phase 2:** Analyze results
- Loads diagnostic results
- Creates summary table
- **Identifies root cause(s)** based on evidence
- Recommends specific fix
- Saves plots (if interactive)

### Expected Runtime

- **Local:** 2-3 hours (100 reps × 6 diagnostics)
- **Slurm (optional):** ~30 minutes with parallel workers

---

## Interpreting Results

### Decision Tree

```
IF Diagnostic 1 (true types) fixes it:
  → Discretization mismatch is root cause
  → FIX: Improve discretization OR increase J (Diagnostic 3)

ELSE IF Diagnostic 2 (individual schemes) fixes it:
  → Ensemble minimum is root cause
  → FIX: Use single best scheme OR median/mean instead of min

ELSE IF Diagnostic 3 (increasing J) fixes it:
  → J=16 too coarse is root cause
  → FIX: Increase default J to required value

ELSE IF Diagnostic 4 (sampling fixes closed-form):
  → Closed-form implementation bug is root cause
  → FIX: Debug and fix closed-form formula in estimate_minimax_single_scheme()

ELSE IF Diagnostic 5 (Wasserstein unaffected):
  → TV-ball specific issue (but need other diagnostics to say which)

ELSE IF Diagnostic 6 (point estimate unbiased):
  → CI construction issue
  → FIX: Adjust bootstrap method or increase samples

ELSE:
  → Fundamental issue with approach
  → Consult theory, advisors, or pivot
```

### What You'll See

**Terminal output includes:**
1. Progress for each diagnostic
2. Coverage rates for each test
3. Mean estimates vs truth
4. **Diagnosis statement** after each test
5. Final summary table
6. **Root cause identification** (from analyze_diagnostics.R)

**Saved outputs:**
- `sims/results/coverage_diagnostics.rds` — Full results
- `sims/results/diagnostic_coverage_plot.pdf` — Coverage comparison
- `sims/results/diagnostic_J_effect.pdf` — Effect of J

---

## Key Implementation Details

### New Function: `compute_type_level_effects()`

Added to `package/R/type_level_minimax.R`:

```r
compute_type_level_effects <- function(data, bins) {
  # Computes tau_s, tau_y, and p0 for each type
  # Used by both closed-form and sampling approaches
  # Returns: list(tau_s, tau_y, p0, J)
}
```

This function extracts type-level treatment effects from discretized data, which is critical for:
1. Closed-form concordance formula
2. Sampling-based verification
3. Diagnostic 4 (comparing approaches)

### Data Generation with True Types

The `generate_data_with_true_types()` function in the diagnostic script:
- Generates J true types with known treatment effects
- Assigns observations to types
- Generates S, Y outcomes based on type-specific effects
- Returns true types alongside data

This enables **oracle testing**: we can compare discretization to ground truth.

### Bootstrap CI for True Types

In Diagnostic 1, we manually bootstrap the true-types estimate since `surrogate_inference_minimax()` always discretizes:

```r
bootstrap_estimates <- numeric(100)
for (b in 1:100) {
  boot_idx <- sample(1:nrow(data), replace = TRUE)
  boot_data <- data[boot_idx, ]
  boot_types <- true_types[boot_idx]  # Bootstrap types too
  boot_est <- estimate_minimax_single_scheme(boot_data, boot_types, ...)
  bootstrap_estimates[b] <- boot_est$phi_value
}
ci <- quantile(bootstrap_estimates, c(0.025, 0.975))
```

---

## After Diagnostics: Next Steps

### Stage 1: Identify Root Cause (This Framework)

**Deliverable:** Clear identification of which diagnostic(s) show improvement
**Timeline:** ~3 hours (run diagnostics + analyze)

### Stage 2: Implement Targeted Fix

Based on diagnostic results, implement one of:

**If discretization mismatch:**
- Option A: Increase J (from Diagnostic 3 results)
- Option B: Better discretization alignment (if feasible)
- Option C: Use observation-level for small n (where discretization worst)

**If ensemble minimum:**
- Option A: Use single best scheme (RF if consistently best)
- Option B: Use median or mean instead of minimum
- Option C: Weighted ensemble based on reliability

**If J too small:**
- Update default `J_target` in package functions
- Add guidance in documentation
- Possibly adaptive J based on sample size

**If closed-form bug:**
- Debug `estimate_minimax_single_scheme()` lines 64-86
- Check: concordance_p0, min_concordance, mixture formula
- Verify formula is theoretically correct

**Timeline:** 1-2 days (implement + test)

### Stage 3: Validation

Once fix implemented:

1. **Test on diagnostic scenario** (100 reps): Should achieve 93-95% coverage
2. **Validation subset** (4,800 reps): 4 sizes × 3 scenarios × 4 λ × 100 reps
   - Pass criteria: min_coverage ≥ 0.90
3. **Full re-run** (if validation passes): Studies 1 & 2 on Slurm
   - Verify final coverage: 93-95%

**Timeline:** 4-6 days (validation + full re-run)

---

## Files Created

### New Scripts

1. **`sims/scripts/diagnostic_coverage_failure.R`**
   - Master diagnostic script
   - Runs all 6 diagnostics
   - Saves results to `.rds`
   - ~700 lines

2. **`sims/scripts/analyze_diagnostics.R`**
   - Loads and analyzes diagnostic results
   - Identifies root cause(s)
   - Recommends specific fix
   - Generates plots
   - ~250 lines

### Modified Files

1. **`package/R/type_level_minimax.R`**
   - Added `compute_type_level_effects()` helper function
   - Used by closed-form and sampling approaches
   - ~50 lines added

### Documentation

1. **`DIAGNOSTIC_FRAMEWORK.md`** (this file)
   - Complete framework documentation
   - How to run, interpret, and act on results

---

## Design Principles

### 1. Evidence-Based Diagnosis

No guessing. Each diagnostic tests a specific hypothesis with clear pass/fail criteria.

### 2. Minimal Assumptions

Use oracle information (true types) when available to isolate issues.

### 3. Systematic Coverage

Test multiple hypotheses in parallel. The root cause will reveal itself through differential performance.

### 4. Reproducible

- Fixed seeds for all replications
- Saved results for analysis
- Clear decision tree for interpretation

### 5. Conservative Sample Size

100 reps per diagnostic (600 total) provides stable estimates while remaining computationally feasible.

### 6. Targeted Fix

Once root cause identified, implement **minimal targeted fix**, not wholesale redesign.

---

## Theoretical Background

### Why Type-Level Innovations Are Necessary

From the plan and user correction:

> "We had been failing to explore the space adequately without types. n-dimensional Dirichlet wouldn't ever find an innovation with say 60% of one type. Only type-level approach allowed us to explore the full type space."

**Key insight:** Type-level innovations are NOT the problem. They're required for efficient TV-ball exploration.

The issue is some aspect of **how we're implementing** the type-level approach:
- Discretization alignment?
- Ensemble aggregation?
- Closed-form formula?
- Number of types?

### TV-Ball Geometry

The TV-ball constraint TV(Q, P₀) ≤ λ is equivalent to:

```
Q = (1-λ)P₀ + λP̃
```

where P̃ is any distribution (the "innovation").

**With types (J-dimensional):**
- P̃_j represents the J type probabilities
- Mixture: Q_j = (1-λ)·P0_j + λ·P̃_j
- Closed-form concordance: φ*(λ) = (1-λ)E_P0[τ_S·τ_Y] + λ·min_j(τ_j^s·τ_j^y)

**Critical assumption:** The J types adequately represent the continuous covariate space.

**If violated:** Discretized min_j ≠ true continuous minimum → underestimation.

### Wasserstein vs TV-Ball

**Wasserstein advantage:**
- Uses continuous geometry via cost matrix
- C[i,j] = ||centroid_i - centroid_j||²
- Cost preserves covariate space structure
- Less sensitive to discretization

**TV-ball disadvantage:**
- Treats types as discrete (no geometry)
- Only constraint is total probability mass
- More sensitive to discretization quality

This is why Diagnostic 5 tests Wasserstein as a control.

---

## Validation History

### Full Simulation Results (Pre-Diagnostic)

**Study 1:** 24,000 replications (4 sizes × 3 scenarios × 4 λ × 500 reps)
- Overall coverage: **64%**
- Worst: 29% (n=250, λ=0.4, low_het_high_cor)

**Study 2:** 10,500 replications (stress testing)
- Similar failure pattern

**Diagnosis from `examine_failed_cases.R`:**
- Mean estimate ≈ min_j (0.093)
- Mean truth ≈ (1-λ)P0 + λ·min_j (0.179)
- **The (1-λ)P0 term is being lost**

This diagnostic framework was created to systematically identify WHY.

---

## Contact and Support

**Primary investigator:** [Your name]
**Created by:** Claude Sonnet 4.5 (2026-03-30)
**Repository:** surrogate-transportability
**Branch:** main

**For questions:**
1. Check this document first
2. Run `analyze_diagnostics.R` to see current results
3. Consult `sims/results/coverage_diagnostics.rds` for raw data

---

## Appendix: Quick Reference

### Commands

```bash
# Run diagnostics
Rscript sims/scripts/diagnostic_coverage_failure.R

# Analyze results
Rscript sims/scripts/analyze_diagnostics.R

# Check saved results
Rscript -e "diag <- readRDS('sims/results/coverage_diagnostics.rds'); str(diag, max.level = 2)"
```

### Expected Coverage Rates

| Approach | Expected Coverage | Interpretation |
|----------|-------------------|----------------|
| Discretized (current) | ~64% | BASELINE (known failure) |
| True types (oracle) | ~95% if discretization is issue | ROOT CAUSE |
| Individual schemes | ~90%+ if ensemble is issue | ROOT CAUSE |
| J=32 or J=64 | ~95% if J=16 too small | ROOT CAUSE |
| Closed-form vs sampling | Should match if correct | IMPLEMENTATION CHECK |
| Wasserstein | ~95% if TV-ball specific | CONTROL |

### File Sizes

- `coverage_diagnostics.rds`: ~5-10 MB (600 replications × detailed results)
- Runtime logs: Printed to console
- Plots: ~100 KB each (PDF)

---

**Last updated:** 2026-03-30
**Status:** Ready to run ✓
