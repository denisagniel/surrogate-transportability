# Validation Methodology Review: What Did We Actually Validate?

**Date:** 2026-03-30
**Context:** Coverage failure diagnostic framework
**Question:** Is the J-dimensional approximation fundamentally adequate?

---

## Executive Summary

**What the validation tested:** J-dimensional (type-level) minimax vs n-dimensional (observation-level) minimax

**What it found:**
- ✅ **Linear τ(X):** <2% error
- ✅ **Step functions:** <2% error
- ❌ **Smooth nonlinear:** 80% error

**Implication:** J-dimensional approximation IS valid for well-behaved treatment effects, but may fail for complex scenarios.

**Current crisis:** 64% coverage suggests our DGP might fall into the "challenging" category, OR J=16 is too small for our specific scenario.

---

## Three Levels of "Truth"

When we say "truth" or "minimax," we need to be precise about which level:

### Level 1: True Continuous Minimax (Unknowable)

```
min_{Q: TV(Q,P0)≤λ, Q has continuous support} E_Q[δ_S · δ_Y]
```

This is the **theoretical ideal** — minimizing over ALL distributions with continuous covariate support that satisfy the TV constraint.

**Problem:** Computationally intractable. Can't enumerate all continuous distributions.

---

### Level 2: Observation-Level Minimax (n-dimensional)

```
min over {Q_m = (1-λ)P0 + λP̃_m, P̃_m ~ Dirichlet_n(1,...,1)}
```

Where `n = sample size`, and we give each observation its own probability mass.

**Characteristics:**
- **n-dimensional** probability simplex
- No discretization of covariate space
- **Slow:** O(n × M) where M = number of innovations
- **Memory intensive:** Need to store n-dimensional innovations

**This is what the validation used as "ground truth"** (see `validate_rf_ensemble_theory.R` line 97):
```r
innovations <- rdirichlet(n_grid, rep(1, n))  # n-dimensional!
```

---

### Level 3: Type-Level Minimax (J-dimensional)

```
min over {Q_m = (1-λ)P0 + λP̃_m, P̃_m ~ Dirichlet_J(1,...,1)}
```

Where `J = number of types` (e.g., J=16), obtained by discretizing observations into types.

**Characteristics:**
- **J-dimensional** probability simplex (J << n)
- Requires discretization (RF, quantiles, k-means)
- **Fast:** O(J × M) where M = number of innovations
- **Closed-form for concordance:** φ*(λ) = (1-λ)E_P0[τ·τ] + λ·min_j(τ_j^s·τ_j^y)

**This is what we implement** in `surrogate_inference_minimax()`.

---

## What the Validation Actually Tested

**Comparison:** Level 3 (J-dimensional) vs Level 2 (n-dimensional)

**From `VALIDATION_RESULTS.md`:**

| Scenario | Level 2 (n-dim) | Level 3 (J-dim, ensemble) | Error |
|----------|-----------------|---------------------------|-------|
| Linear τ(X) | 1.000 | 0.984 | -1.6% |
| Step τ(X) | 0.991 | 0.979 | -1.3% |
| Smooth nonlinear | 0.364 | 0.071 | -80.6% |

**Key finding:** J-dimensional works well for simple treatment effect structures, poorly for complex ones.

---

## The Approximation Chain

```
Level 1 (True continuous minimax)
   ↓ [Approximation 1: Finite sample + Dirichlet simplex]
Level 2 (n-dimensional observation-level)
   ↓ [Approximation 2: Discretization into J types]
Level 3 (J-dimensional type-level)
```

**Validation tested Approximation 2.**

**Coverage failure could be due to:**
1. **Approximation 2 breaking down** (J=16 inadequate for this DGP)
2. **Implementation bug** in Level 3 code
3. **Both** approximations stacking up

---

## Why Observation-Level Is "Ground Truth"

**It's NOT the true continuous minimax**, but it's the best we can compute:

1. **Finite sample:** We only have n observations, so continuous Q is already discretized to n support points
2. **Dirichlet simplex:** Restricting to Dirichlet innovations is computationally feasible while still exploring the TV ball
3. **No discretization bias:** Each observation gets its own probability mass — no aggregation into types

**Analogy:** It's like comparing:
- **Fine grid (n=250 points)** ← observation-level
- **Coarse grid (J=16 points)** ← type-level

The fine grid is "ground truth" for practical purposes, even though the TRUE function is continuous.

---

## What Diagnostic 7 Tests

**Diagnostic 7: Observation-Level vs Type-Level**

```r
# A. Type-level (J=16, current)
surrogate_inference_minimax(..., J_target = 16)

# B. Observation-level (n-dimensional, no discretization)
# Generate n-dimensional Dirichlet innovations
innovations <- rdirichlet(M, rep(1, n))
# Compute minimax via direct reweighting (no types)
```

**If observation-level gives 95% coverage but type-level gives 64%:**
→ **Approximation 2 is failing** (J-dimensional inadequate)

**If both give 64% coverage:**
→ **Issue is elsewhere** (implementation bug, bootstrap, etc.)

**If both give 95% coverage:**
→ **Neither is the issue** (something wrong with "truth" calculation in simulation)

---

## Theoretical Foundations

### TV-Ball Geometry

The TV constraint TV(Q, P0) ≤ λ is equivalent to:
```
Q = (1-λ)P0 + λP̃
```
where P̃ is ANY distribution (the "innovation").

**With finite sample:**
- P0 = empirical distribution (1/n mass on each observation)
- P̃ = any distribution on the same n observations
- Q = weighted mixture

**Level 2 (n-dim):** P̃ can put arbitrary mass on any of the n observations
**Level 3 (J-dim):** P̃ can only put mass on J type centroids

---

### When Does J-Dimensional Work?

**Works well when:**
- Treatment effects τ(X) are **simple functions** of covariates
  - Linear: τ = β^T X
  - Step: τ = Σ_k τ_k · I(X ∈ R_k)
  - Low-dimensional: τ depends on 1-2 key covariates

**Fails when:**
- Treatment effects are **complex/nonlinear** functions
  - High-order interactions
  - Smooth continuous variation
  - Many relevant covariates (curse of dimensionality)

**Our DGP (low_het_high_cor):**
```r
tau_y <- rnorm(J, mean = 0.5, sd = 0.1)
tau_s <- 0.9 * tau_y + sqrt(1 - 0.9^2) * rnorm(J, sd = 0.1)
```

**This creates:**
- J=16 discrete types (simple structure)
- High correlation (ρ=0.9)
- Low heterogeneity (cv=0.1)

**Should work well!** Unless:
1. J=16 is still too coarse for n=250
2. Discretization methods don't recover the true types
3. Implementation bug

---

## Why Our DGP Should Work

**Evidence it should work:**

1. **DGP has discrete types:** Data is GENERATED with J=16 types, not continuous
2. **Simple structure:** Treatment effects are just normal draws, not complex functions
3. **Validated scenarios:** Similar to "step function" case (1.3% error in validation)

**So why 64% coverage?**

**Possible explanations:**
1. **Discretization mismatch** (Diagnostic 1): Our RF/quantiles/kmeans don't recover the true types
2. **J=16 still too small** (Diagnostic 3): Need J=32 or J=64
3. **Ensemble minimum issue** (Diagnostic 2): Taking min across schemes amplifies errors
4. **Implementation bug** (Diagnostic 4): Closed-form formula wrong
5. **Bootstrap issue** (Diagnostic 6): CIs too narrow

**Diagnostic 7 tells us if it's fundamentally the J-dimensional approach** or one of the specific implementation issues above.

---

## Validation vs Current Problem

### Validation Setup

**Data generation:**
```r
# Known treatment effect functions
tau_s <- function(X) β_s^T X  # Linear
tau_y <- function(X) β_y^T X
```

**Ground truth:** n-dimensional minimax (M=1000 innovations)
**Estimate:** J-dimensional with RF, quantiles, k-means
**Result:** 1-2% error

### Our Simulation Setup

**Data generation:**
```r
# J=16 discrete types
tau_y[j] ~ N(0.5, 0.1)
tau_s[j] = 0.9 * tau_y[j] + ε
# Assign observations to types
```

**Ground truth:** Closed-form from true parameters:
```r
true_minimax = (1-λ) * sum(π_j * tau_s[j] * tau_y[j]) + λ * min_j(tau_s[j] * tau_y[j])
```

**Estimate:** J-dimensional with RF, quantiles, k-means (same as validation)
**Result:** 64% coverage (systematic underestimation)

### Key Difference

**Validation:** Compared J-dim estimate to n-dim "ground truth" (both estimated)
**Our sims:** Compare J-dim estimate to DGP truth (known exactly)

**Why this matters:**
- In validation, both methods have **sampling error**
- In our sims, truth is **exact** (no sampling error)
- Our sims are a **stricter test**

---

## What Diagnostic 7 Adds

**Completes the picture:**

```
Truth (DGP parameters)
   ↓
Level 2 (n-dimensional)  ← Test in Diagnostic 7
   ↓
Level 3 (J-dimensional)  ← Current implementation
```

**Diagnostic 7 tests:**
- Does Level 2 (n-dim) achieve 95% coverage against DGP truth?
- Does Level 3 (J-dim) achieve 95% coverage against DGP truth?
- How much error does Approximation 2 (J-dim vs n-dim) add?

**Possible outcomes:**

| Level 2 (n-dim) | Level 3 (J-dim) | Interpretation |
|-----------------|-----------------|----------------|
| 95% | 64% | **Approximation 2 fails** (J-dim inadequate) |
| 64% | 64% | **Both fail** (issue is Approximation 1 or truth calculation) |
| 95% | 95% | **Both work** (bug in how we computed "truth" in Studies 1&2) |

---

## Practical Implications

### If Diagnostic 7 shows J-dimensional is inadequate:

**Short-term fix:**
- Increase J from 16 to [value from Diagnostic 3]
- OR use observation-level for small n (n < 500)

**Long-term solution:**
- Adaptive J: larger J for smaller n
- Hybrid: observation-level for n < 500, type-level for n ≥ 500

### If Diagnostic 7 shows both fail:

**Re-examine assumptions:**
- Is DGP truth computed correctly?
- Are we testing the right estimand?
- Is Approximation 1 (Dirichlet simplex) inadequate?

### If Diagnostic 7 shows both work:

**Bug in Studies 1 & 2:**
- Truth calculation wrong
- Wrong formula for closed-form
- Different DGP than intended

---

## Computational Considerations

**Why not always use observation-level?**

| Aspect | Observation-level | Type-level |
|--------|-------------------|------------|
| **Complexity** | O(n × M) | O(J × M) |
| **Speed (n=250)** | ~1-2 hours | ~2-3 minutes |
| **Memory** | n × M matrix | J × M matrix |
| **Scalability** | Poor (n=10,000 infeasible) | Good (J=100 feasible) |
| **Closed-forms** | No | Yes (for concordance) |

**For n=250, M=2000:**
- Observation-level: 250 × 2000 = 500,000 computations
- Type-level (J=16): 16 × 2000 = 32,000 computations
- **Speedup: 15×**

**Type-level is a computational necessity for large n.**

---

## Recommendations

### Immediate (Run Diagnostics)

1. **Run Diagnostics 1-6** (2-3 hours) — identify practical issues
2. **Optionally run Diagnostic 7** (1-2 hours) — test fundamental approximation
3. **Analyze results** — identify root cause(s)

### Based on Diagnostic 7 Results

**If observation-level works (95% coverage):**
- **Confirms:** J-dimensional approximation is the bottleneck
- **Fix:** Increase J or use observation-level for small n
- **Validates:** Theoretical approach is sound, just need better approximation

**If observation-level also fails (64% coverage):**
- **Investigate:** Truth calculation, formula implementation
- **Revisit:** Dirichlet simplex assumption
- **Consult:** Theory, advisors

### Long-Term (After Fix)

1. **Document limits:** When does J-dimensional work? (depends on DGP complexity and n)
2. **Adaptive methods:** J = f(n, complexity)
3. **Hybrid approach:** Observation-level for small n, type-level for large n

---

## Conclusion

**The validation methodology is sound:**
- Observation-level (n-dimensional) is valid "ground truth"
- Type-level (J-dimensional) is a computational approximation
- Validation showed approximation works for simple τ(X), fails for complex τ(X)

**Current crisis (64% coverage) could be:**
1. **Our DGP falls into "complex" category** (unlikely given discrete types)
2. **J=16 too small for n=250** (likely — Diagnostics 1 & 3 will confirm)
3. **Implementation bug** (possible — Diagnostic 4 will confirm)
4. **Multiple issues stacking up** (most likely)

**Diagnostic 7 completes the picture** by testing whether the fundamental J-dimensional approximation is adequate, or whether we need to fix implementation details first.

---

**Last updated:** 2026-03-30
**Status:** Diagnostic framework ready to run
**Next step:** Execute diagnostics and analyze results
