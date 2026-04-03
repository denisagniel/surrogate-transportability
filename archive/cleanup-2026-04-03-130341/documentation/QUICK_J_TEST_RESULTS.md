# Quick J Test Results: CRITICAL FINDING

**Date:** 2026-03-30
**Test:** Does increasing J fix the secondary coverage issue?
**Status:** ✅ COMPLETE - **NEGATIVE RESULT**

---

## Summary

**Increasing J makes coverage WORSE, not better.**

| J | Coverage | Bias | Mean Estimate | Mean Truth |
|---|----------|------|---------------|------------|
| 16 | 50.0% | -0.064 | 0.110 | 0.174 |
| 32 | 36.7% | -0.089 | 0.081 | 0.170 |
| 64 | **0.0%** | **-0.357** | **-0.190** | 0.167 |

**Pattern: As J increases, coverage decreases and bias worsens.**

---

## Critical Observations

### 1. Coverage Degrades with J

- J=16: 50% coverage
- J=32: 37% coverage (13 percentage points worse)
- J=64: 0% coverage (complete failure)

**This is the OPPOSITE of what we expected.** More types should improve approximation, not destroy it.

### 2. Estimates Become Catastrophically Biased

- J=16: Estimate = 0.110 (truth = 0.174) → 37% underestimation
- J=32: Estimate = 0.081 (truth = 0.170) → 52% underestimation
- J=64: Estimate = **-0.190** (truth = 0.167) → **Negative when truth is positive!**

### 3. Bias Compounds with J

- J=16: Bias = -0.064
- J=32: Bias = -0.089 (39% worse)
- J=64: Bias = -0.357 (456% worse than J=16)

---

## Why This Happens

### Smaller Bins = Noisier Estimates

With n=250 observations:
- J=16: ~16 obs per bin on average
- J=32: ~8 obs per bin
- J=64: **~4 obs per bin** (too sparse!)

As bins get smaller:
- Within-bin treatment effect estimates τ̂_j become noisier
- Standard errors increase
- Extreme values become more likely

### Minimum Amplifies Noise

The closed-form formula uses: **φ*(λ) = (1-λ)E_P0[τ·τ] + λ·min_j(τ_j^s·τ_j^y)**

With noisy estimates:
- τ̂_j^s · τ̂_j^y has large variance when bins are small
- **min_j selects the most extreme negative value**
- This is a downward-biased estimator (min of noisy positives tends negative)

At J=64:
- With 64 noisy concordance estimates
- Minimum is very likely to be an extreme negative outlier
- Result: Estimate = -0.190 when truth ≈ 0.17

---

## Comparison to Other Results

### From Diagnostic 1 (n=250, λ=0.4, J=16)

| Approach | Coverage | Bias | Mean Estimate | Truth |
|----------|----------|------|---------------|-------|
| **True types (oracle)** | **65%** | -0.056 | 0.122 | 0.178 |
| **Discretized ensemble** | **8%** | -0.172 | 0.006 | 0.178 |

### From Quick J Test (n=250, λ=0.4, quantiles only)

| Approach | Coverage | Bias | Mean Estimate | Truth |
|----------|----------|------|---------------|-------|
| **Quantiles J=16** | **50%** | -0.064 | 0.110 | 0.174 |
| **Quantiles J=32** | **37%** | -0.089 | 0.081 | 0.170 |
| **Quantiles J=64** | **0%** | -0.357 | -0.190 | 0.167 |

### Key Insights from Comparison

**1. Ensemble minimum makes it worse:**
- Quantiles alone (J=16): 50% coverage
- Ensemble min over RF+quantiles+kmeans: 8% coverage
- **Taking minimum across schemes drops coverage by 42 percentage points**

**2. But quantiles alone still fails:**
- Quantiles (J=16): 50% coverage vs 95% needed
- Even without ensemble, single scheme is inadequate

**3. Oracle types perform best:**
- True types: 65% coverage (still not 95%, but much better)
- Discretized: 8-50% coverage depending on scheme/ensemble
- **Discretization quality is a major bottleneck**

---

## Root Causes Identified

### Primary Issues

**1. Ensemble Minimum Amplifies Errors**
- Evidence: 50% (single scheme) → 8% (ensemble)
- Mechanism: Selects worst-performing scheme
- With noisy estimates, "worst" is systematically biased down

**2. Discretization Creates Noisy Bins**
- Evidence: 65% (oracle) → 50% (quantiles J=16)
- Mechanism: Quantiles discretization based on X, not (τ_s, τ_y)
- Bins don't align with true type structure

**3. Minimum Over Noisy Estimates Has Downward Bias**
- Evidence: As J increases (more estimates), bias worsens
- Mechanism: min_j(τ̂_j^s · τ̂_j^y) where τ̂_j are noisy
- Larger J = more chances to select extreme negative outlier

### Secondary Issue

**4. Small Bins Reduce Estimation Precision**
- Evidence: J=64 gives n/J ≈ 4 obs per bin
- Mechanism: Too few observations to estimate τ_j accurately
- Result: High variance → extreme min → catastrophic bias

---

## What This Rules Out

**❌ J=16 is too small:** FALSE
- Increasing J makes it worse, not better
- J=16 with quantiles gives 50% coverage
- J=64 with quantiles gives 0% coverage

**❌ Need more types for TV-ball approximation:** FALSE
- The TV-ball approximation improves with J in THEORY
- But discretization and minimum operation break down in PRACTICE
- Trade-off: better approximation vs noisier estimates

---

## What This Confirms

**✓ Ensemble minimum is problematic**
- 50% (single) → 8% (ensemble) is a 42 point drop
- Should test Diagnostic 2: individual schemes vs ensemble

**✓ Discretization quality matters**
- 65% (oracle) vs 50% (quantiles) at same J=16
- Quantiles don't recover true type structure
- Need better alignment, not just more bins

**✓ Closed-form formula may have issues**
- min_j operator on noisy estimates creates bias
- Should test Diagnostic 4: closed-form vs sampling
- Sampling approach might handle noise better

---

## Implications for Fix Strategy

### DO NOT:
- ❌ Increase default J (makes it worse)
- ❌ Use J > 32 (too noisy at n=250)
- ❌ Focus only on discretization alignment (not sufficient)

### DO:
1. **Fix ensemble aggregation** (Diagnostic 2)
   - Test median/mean instead of minimum
   - Or use single best scheme (likely RF)

2. **Test closed-form implementation** (Diagnostic 4)
   - Sampling-based approach may be more robust to noise
   - Closed-form min_j might be fundamentally problematic

3. **Improve discretization** (Diagnostic 1 showed this helps)
   - Oracle types give 65% vs 50% for quantiles
   - But need method that's feasible in practice

4. **Consider adaptive J**
   - J should decrease as n decreases (more obs per bin)
   - Rule: J ≤ n/10 or J ≤ √n to maintain bin sizes

---

## Next Steps

### Immediate (Hours)

1. **Run Diagnostic 2: Ensemble vs Individual Schemes**
   - Test: RF only, quantiles only, kmeans only, ensemble
   - Hypothesis: Individual schemes perform better than ensemble minimum
   - Expected: RF or quantiles alone gives 50-70% coverage

2. **Run Diagnostic 4: Closed-Form vs Sampling**
   - Test: Current closed-form vs Dirichlet sampling approach
   - Hypothesis: Sampling is more robust to noisy type-level estimates
   - Expected: Sampling gives better coverage (less affected by min operation)

3. **Fix remaining diagnostics** (tibble error)
   - Apply explicit value extraction fix to Diagnostics 2-6
   - Run complete suite (2-3 hours)

### After Diagnostics (Days)

**If Diagnostic 2 shows individual schemes work:**
- Switch from ensemble minimum to single best scheme (likely RF)
- Or use median/mean aggregation instead of minimum

**If Diagnostic 4 shows sampling works:**
- Use sampling-based approach instead of closed-form
- Trade-off: slower computation for better coverage

**If both needed:**
- Combine fixes: Use RF scheme + sampling approach
- This may be the robust solution

---

## Test Configuration

**Scenario:** Worst-case from full simulations
- n = 250
- λ = 0.4
- rho = 0.9
- cv = 0.1
- scenario = "low_het_high_cor"

**Discretization:** Quantiles only (not ensemble)
**J values tested:** 16, 32, 64
**Replications:** 30 per J (90 total)
**Runtime:** ~30 minutes

**Results file:** `sims/results/quick_test_J_effect.rds`

---

## Conclusion

**The coverage issue is NOT due to J being too small.**

Increasing J from 16 → 32 → 64 makes coverage worse (50% → 37% → 0%), not better. This reveals that the problem is not the TV-ball approximation quality (which improves with J), but rather:

1. **Ensemble minimum** systematically selects worst scheme (50% → 8%)
2. **Discretization quality** doesn't match true types (65% oracle vs 50% quantiles)
3. **Minimum operation** on noisy estimates has catastrophic downward bias
4. **Small bins** (large J) produce unstable estimates

**Priority actions:**
1. Test individual schemes (Diagnostic 2) - likely shows 50-70% coverage
2. Test sampling vs closed-form (Diagnostic 4) - may fix min_j noise issue
3. Fix both if needed

**Do NOT increase J.** The solution lies elsewhere.

---

**Status:** Test complete, interpretation documented
**Next:** Run Diagnostics 2 and 4 to identify specific fix
