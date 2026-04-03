# Diagnostic Interpretation Guide

**Date:** 2026-03-30
**Status:** Running complete diagnostic suite
**Expected completion:** 2-3 hours

---

## What We Know So Far

### Diagnostic 1 Results (COMPLETED)

| Approach | Coverage | Bias | Mean Estimate | Truth |
|----------|----------|------|---------------|-------|
| **Discretized (ensemble)** | **8%** | -0.172 | 0.006 | 0.178 |
| **True types (oracle)** | **65%** | -0.056 | 0.122 | 0.178 |

**Key finding:** TWO separate problems identified
1. **Primary (57 points):** Discretization quality (8% → 65%)
2. **Secondary (30 points):** Unknown issue (65% → 95%)

### Quick J Test Results (COMPLETED)

| Approach | J | Coverage | Bias | Mean Estimate | Truth |
|----------|---|----------|------|---------------|-------|
| Quantiles only | 16 | 50.0% | -0.064 | 0.110 | 0.174 |
| Quantiles only | 32 | 36.7% | -0.089 | 0.081 | 0.170 |
| Quantiles only | 64 | 0.0% | -0.357 | -0.190 | 0.167 |

**Key finding:** Increasing J makes it WORSE (opposite of expected)
- J size is NOT the issue
- Larger J creates noisier within-bin estimates
- min_j operation amplifies downward bias with noise

### Comparison Table

| Approach | J | Scheme(s) | Coverage |
|----------|---|-----------|----------|
| Oracle (true types) | 16 | N/A | **65%** |
| Quantiles only | 16 | Quantiles | **50%** |
| Ensemble | 16 | RF+Quantiles+Kmeans (min) | **8%** |
| Quantiles only | 64 | Quantiles | **0%** |

**Pattern identified:**
1. Oracle > Single scheme > Ensemble
2. Discretization quality: 65% (oracle) vs 50% (quantiles)
3. Ensemble minimum: 50% (quantiles) → 8% (ensemble) = 42 point drop
4. Increasing J destroys performance: 50% → 37% → 0%

---

## What Each Diagnostic Tests

### Diagnostic 2: Individual Schemes vs Ensemble

**Hypothesis:** Taking minimum across RF/quantiles/k-means amplifies errors

**Tests:**
- RF only (100 reps)
- Quantiles only (100 reps)
- K-means only (100 reps)
- Ensemble minimum (100 reps)

**Expected results:**
- **If ensemble is the problem:** Individual schemes give 50-70% coverage, ensemble gives 8%
- **If all schemes fail:** All give <30% coverage (ensemble not the issue)
- **If one scheme works:** That scheme gives 90%+, others fail

**Interpretation guide:**

| RF | Quantiles | Kmeans | Ensemble | Diagnosis |
|----|-----------|--------|----------|-----------|
| 70% | 50% | 40% | 8% | **Ensemble minimum is the ROOT CAUSE** |
| 90%+ | 50% | 40% | 8% | **Use RF only** (best single scheme) |
| 30% | 30% | 30% | 8% | **All schemes fail** (not ensemble issue) |

**Action if confirmed:**
- Switch from ensemble minimum to best single scheme (likely RF)
- OR use median/mean aggregation instead of minimum

---

### Diagnostic 3: Effect of J

**Already covered by quick J test - results show J is NOT the issue**

This diagnostic will provide more data points but we already know:
- J=16: 50% (quantiles), 8% (ensemble)
- J=32: 37% (worse)
- J=64: 0% (catastrophic failure)

**Conclusion:** Do NOT increase J

---

### Diagnostic 4: Closed-Form vs Sampling

**Hypothesis:** Bug in closed-form implementation

**Tests (using TRUE TYPES to isolate formula):**
- **Closed-form:** Current implementation: φ*(λ) = (1-λ)E_P0[τ·τ] + λ·min_j(τ_j^s·τ_j^y)
- **Sampling:** Brute force: Generate 5000 Dirichlet innovations, compute minimum
- **Theoretical:** True value from DGP parameters

**Expected results:**
- **If closed-form has bug:** Closed ≠ Sampling ≈ Theoretical
- **If both correct:** Closed ≈ Sampling ≈ Theoretical
- **If both biased:** Closed ≈ Sampling ≠ Theoretical (issue is elsewhere)

**Interpretation guide:**

| Closed-form | Sampling | Theoretical | Diagnosis |
|-------------|----------|-------------|-----------|
| 0.120 | 0.178 | 0.178 | **FORMULA BUG** in closed-form |
| 0.120 | 0.120 | 0.178 | **Both biased** (not formula bug) |
| 0.178 | 0.178 | 0.178 | **Both correct** (issue is discretization) |

**Action if bug found:**
- Debug lines 64-86 in `estimate_minimax_single_scheme()`
- Check: concordance_p0 calculation, min_concordance calculation, mixture formula
- Possibly: Closed-form is theoretically wrong (consult theory)

**Action if sampling works:**
- Switch to sampling-based approach (slower but more robust)
- Trade computation time for coverage

---

### Diagnostic 5: TV-Ball vs Wasserstein

**Hypothesis:** Issue is specific to TV-ball geometry

**Tests:**
- TV-ball minimax (current, 8% coverage)
- Wasserstein minimax (unknown coverage)

**Expected results:**
- **If TV-ball specific:** Wasserstein gives 90%+ coverage
- **If both affected:** Wasserstein also gives <50% coverage
- **Confound:** λ scales differ between TV and Wasserstein (not directly comparable)

**Interpretation:**
This is a secondary diagnostic. If Wasserstein works, it suggests TV-ball geometry is problematic, but we'd still need to fix the TV-ball implementation (not switch methods).

---

### Diagnostic 6: Point Estimate vs CI Width

**Hypothesis:** Point estimate is fine, CI too narrow

**Already ruled out** by existing data:
- Mean estimate: 0.093
- Mean truth: 0.179
- Difference: 0.086 (almost 2× the estimate)

This is clearly a **bias issue**, not a CI width issue.

**Diagnostic 6 will confirm** by analyzing:
- Z-scores (should be ~0 if well-calibrated)
- Truth above CI (should be 2.5% for two-tailed 95% CI)

**Expected:** Z-score >> 2, confirming point estimate is biased

---

### Diagnostic 7: Observation-Level vs Type-Level

**Hypothesis:** J-dimensional approximation is fundamentally inadequate

**Tests (SLOW - only 30 reps):**
- **Type-level:** Current J=16 discretized approach (ensemble)
- **Observation-level:** n-dimensional Dirichlet (no discretization)

**Expected results:**
- **If approximation fails:** Obs-level 90%+, Type-level 8%
- **If both fail:** Both give <50% coverage
- **If both work:** Both give 90%+ (issue is truth calculation)

**Interpretation guide:**

| Obs-level | Type-level | Diagnosis |
|-----------|------------|-----------|
| 95% | 8% | **J-dimensional inadequate** (fundamental issue) |
| 50% | 8% | **Both have problems** (approximation + implementation) |
| 95% | 95% | **Truth calculation wrong** (methods work) |

**Action if obs-level works:**
- Use observation-level for small n (n < 500)
- Use type-level for large n (n ≥ 500)
- Hybrid approach based on sample size

**Note:** This is the most theoretically important test but SLOWEST (1-2 hours just for this diagnostic).

---

## Decision Tree

After all diagnostics complete:

```
START
  ↓
Does Diagnostic 2 show individual scheme(s) work?
  ↓
  YES → FIX: Use best single scheme (likely RF) instead of ensemble minimum
  |     ↓
  |     If still <90% coverage after fix:
  |       ↓
  |       Does Diagnostic 4 show sampling works?
  |         ↓
  |         YES → FIX: Switch to sampling-based approach
  |         NO  → Investigate discretization quality (Diagnostic 1)
  ↓
  NO → All schemes fail
       ↓
       Does Diagnostic 4 show closed-form has bug?
         ↓
         YES → FIX: Debug formula implementation
         |     Re-test after fix
         ↓
         NO → Both closed-form and sampling biased
              ↓
              Does Diagnostic 7 show obs-level works?
                ↓
                YES → FIX: Use observation-level for small n
                NO  → DEEPER PROBLEM (consult advisors)
```

---

## Priority Actions Based on Results

### Scenario A: Diagnostic 2 shows RF gives 70%+, ensemble gives 8%

**ROOT CAUSE:** Ensemble minimum
**FIX:** Use RF only
**Expected improvement:** 8% → 70% coverage
**Implementation time:** 1 hour (change one line)

### Scenario B: Diagnostic 4 shows sampling ≈ truth, closed-form ≠ truth

**ROOT CAUSE:** Closed-form formula bug
**FIX:** Debug lines 64-86 or switch to sampling
**Expected improvement:** 8% → 90%+ coverage
**Implementation time:** 2-4 hours (debug) or 1 day (sampling)

### Scenario C: Diagnostic 2 shows all fail + Diagnostic 4 shows both biased

**ROOT CAUSE:** Unknown (likely discretization + formula)
**FIX:** Multiple changes needed
- Fix discretization quality
- Switch to sampling approach
- Use RF scheme only
**Expected improvement:** 8% → 50% → 70% → 90% (cumulative)
**Implementation time:** 2-3 days

### Scenario D: Diagnostic 7 shows obs-level works, type-level fails

**ROOT CAUSE:** J-dimensional approximation inadequate
**FIX:** Hybrid approach
- Observation-level for n < 500
- Type-level for n ≥ 500
**Expected improvement:** 8% → 95% for small n
**Implementation time:** 3-4 days

---

## Validation Plan After Fix

Once root cause identified and fix implemented:

**Stage 1:** Quick validation (2 hours)
- Test fix on diagnostic scenario (n=250, λ=0.4)
- Run 100 reps
- Target: 90-95% coverage

**Stage 2:** Subset validation (6 hours)
- 4 sample sizes × 3 scenarios × 4 λ values × 100 reps = 4,800 reps
- All settings should achieve ≥90% coverage

**Stage 3:** Full re-run (8-12 hours each)
- Study 1: 24,000 reps
- Study 2: 10,500 reps
- Overall coverage: 93-95%

**Timeline:** ~1 week from diagnosis to validated solution

---

## Files Being Generated

**Results:**
- `sims/results/coverage_diagnostics.rds` - Full diagnostic data
- `sims/results/diagnostic_log.txt` - Console output

**Analysis:**
- Run: `Rscript sims/scripts/analyze_diagnostics.R`
- Reads: `coverage_diagnostics.rds`
- Outputs: Summary tables and root cause identification

---

## Current Status

**Running:** Complete diagnostic suite (all 7 diagnostics)
**Started:** 2026-03-30
**Expected completion:** 2-3 hours
**Total reps:** ~700 (100 for most diagnostics, 30-50 for slow ones)

**Next steps:**
1. Wait for completion (will be notified)
2. Run analysis script
3. Identify root cause from decision tree
4. Implement targeted fix
5. Validate

---

**Last updated:** 2026-03-30 (during diagnostic run)
