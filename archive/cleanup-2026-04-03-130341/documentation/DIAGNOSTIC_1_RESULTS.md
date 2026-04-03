# Diagnostic 1 Results: Critical Discovery

**Date:** 2026-03-30
**Test:** True Types vs Discretized Types
**Status:** ✅ COMPLETE

---

## Summary

**Discretization quality IS a major problem, but NOT the only problem.**

---

## Results

| Approach | Coverage | Bias | Mean Est | Truth |
|----------|----------|------|----------|-------|
| **Discretized** (current RF/quantiles/kmeans) | **8%** | -0.172 | 0.006 | 0.178 |
| **True types** (oracle, no discretization) | **65%** | -0.056 | 0.122 | 0.178 |

**Improvement: 8% → 65% coverage (57 percentage points!)**

---

## Key Findings

### 1. Discretization Quality: MAJOR ISSUE

- Current discretization methods (RF, quantiles, k-means) are **severely underestimating**
- Mean estimate with discretization: **0.006** (should be ~0.178)
- This is **30× too small!**
- Only 8% coverage (catastrophic)

**Why this matters:**
- The discretization methods are creating bins that don't align with the true type structure
- With J=16 discrete types in the DGP, discretization should work well
- But it doesn't → discretization quality is terrible

### 2. True Types: PARTIAL FIX

- With oracle (true types from DGP), coverage improves to **65%**
- Mean estimate: 0.122 (closer to truth of 0.178)
- Bias: -0.056 (still underestimating)

**This is much better, but still not good enough!**
- Still systematic underestimation
- Only 65% coverage (need 95%)
- **There's a SECOND issue beyond discretization**

### 3. Multiple Root Causes

**The 64% coverage failure (from full simulations) breaks down into:**

1. **~56% of the problem:** Discretization quality
   - Discretization fails catastrophically (8% coverage)
   - True types improve to 65%
   - **Difference: 57 percentage points**

2. **~30% of the problem:** Something else
   - Even with true types, only 65% coverage (need 95%)
   - **Missing: 30 percentage points**
   - Possible causes:
     - J=16 still too small (need J=32 or J=64?)
     - Implementation bug in closed-form formula?
     - Bootstrap CI too narrow?
     - Ensemble minimum issue?

---

## Implications

### Immediate

**Discretization is the PRIMARY bottleneck:**
- Current schemes (RF/quantiles/k-means) completely fail
- With oracle types, we get closer but not there yet

**Action needed:**
1. Fix discretization quality (improve alignment with true types)
2. Address the secondary issue (likely J size or formula bug)

### Diagnostic Interpretation

**If Diagnostic 3 (Increasing J) shows:**
- J=32 gives ~80% coverage with discretization → **J is part of the issue**
- J=64 gives ~93% coverage with discretization → **J=16 is too small**

**If Diagnostic 4 (Closed-form vs Sampling) shows:**
- Sampling gives unbiased results but closed-form biased → **Formula bug**
- Both biased similarly → **Not a formula issue**

---

## Why Is Discretization So Bad?

**Hypothesis:**

Even though the DGP has J=16 discrete types, the discretization methods (RF, quantiles, k-means) are:

1. **Not recovering the true type structure**
   - RF: Trains on treated units only, predicts treatment effects
   - Quantiles: Bins on covariate values (X)
   - K-means: Clusters on covariates
   - **None of these directly target the true type assignments!**

2. **Creating misaligned bins**
   - True types are defined by (tau_s, tau_y) pairs
   - Discretization creates bins based on covariates (X)
   - The relationship X → (tau_s, tau_y) may be complex

3. **J=16 may be adequate BUT**
   - Need the RIGHT 16 bins
   - Current methods find the WRONG 16 bins
   - **Quality matters more than quantity**

---

## What We Need

### Short-term (to get coverage from 65% → 95%)

1. **Test if J matters** (Diagnostic 3)
   - Does increasing J with discretization help?
   - Or is the alignment hopeless?

2. **Test formula implementation** (Diagnostic 4)
   - Is closed-form formula correct?
   - Does sampling-based approach work better?

3. **Test ensemble effect** (Diagnostic 2)
   - Does taking minimum across schemes hurt?
   - Do individual schemes perform better?

### Long-term (production fix)

**Option A: Better discretization**
- Improve alignment with true types
- Use treatment effect estimates directly
- Adaptive/data-driven bin selection

**Option B: Increase J**
- Use J=64 or J=100 instead of J=16
- Reduces discretization mismatch
- But slower (more computations)

**Option C: Observation-level for small n**
- Use n-dimensional for n < 500
- Use J-dimensional for n ≥ 500
- Hybrid approach

**Option D: Fix both**
- Better discretization methods (Option A)
- AND larger J (Option B)
- Likely needed given dual causation

---

## Next Steps

1. **Run Diagnostics 2-6** (need to fix the tibble error first)
2. **Analyze complete results** with `analyze_diagnostics.R`
3. **Implement targeted fix** based on which diagnostics show improvement
4. **Validate** on subset (4,800 reps)
5. **Full re-run** Studies 1 & 2

---

## Comparison to Validation

**Validation claimed:**
- "<2% approximation error" for step functions
- Our DGP has discrete types (similar to step functions)

**But we see:**
- Discretization gives 0.006 estimate (truth 0.178) = **97% error!**
- Even true types give 0.122 estimate (truth 0.178) = **31% error!**

**Why the discrepancy?**

Possible explanations:
1. **Validation used n-dimensional as "ground truth"**
   - Our "truth" is exact (DGP parameters)
   - Validation "truth" had sampling error
   - Harder test

2. **Our λ=0.4 is more extreme than validation**
   - Higher λ = worse-case further from P0
   - Harder to approximate

3. **Concordance functional may be harder than correlation**
   - Validation tested correlation
   - We're testing concordance (E[δ_S·δ_Y])
   - Different functional properties

---

**Status:** Diagnostic 1 complete, Diagnostics 2-6 need error fix
**Next:** Fix tibble creation in remaining diagnostics, then run complete suite
