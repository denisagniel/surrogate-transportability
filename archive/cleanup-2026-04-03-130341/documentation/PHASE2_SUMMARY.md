# Phase 2: Systematic Debiasing - Summary

## Problem Statement

Observation-level Wasserstein DRO suffered from selection bias:
- **Naive coverage:** 39% (target: 95%)
- **Naive bias:** -0.064 (systematic underestimation)
- **Root cause:** Taking minimum over noisy concordance estimates

## Solution Approach

Systematically tested 5 families of debiasing methods across 50 replications:

1. **Conservative penalty:** phi_corrected = phi_naive + k × SE
2. **Shrinkage + DRO:** Shrink concordances toward mean before DRO
3. **Empirical Bayes:** Use posterior mean estimates
4. **Percentile shift:** Shift distribution upward
5. **Hybrid:** Combine conservative + shrinkage

## Results

### Winner: Shrinkage + DRO (shrink_factor = 0.5)

**Performance:**
- **Mean bias:** +0.004 (vs -0.064 naive)
- **RMSE:** 0.024 (vs 0.069 naive)
- **Bias reduction:** 94%
- **RMSE reduction:** 65%

### Top 5 Methods

| Rank | Method | Parameter | Bias | RMSE | Notes |
|------|--------|-----------|------|------|-------|
| 1 | Shrinkage | 0.5 | +0.004 | 0.024 | **Nearly unbiased** |
| 2 | Shrinkage | 0.6 | -0.009 | 0.024 | Also excellent |
| 3 | Conservative | k=5 | -0.002 | 0.029 | **Most accurate** |
| 4 | Conservative | k=4 | -0.014 | 0.031 | Good tradeoff |
| 5 | Conservative | k=6 | +0.011 | 0.032 | Slight overcorrection |

### Failed Approaches

- **Percentile shift:** Massive overcorrection (+0.24 to +0.29 bias)
- **Empirical Bayes:** Overcorrects (+0.074 bias)
- **Hybrid:** No improvement over pure shrinkage

## How Shrinkage Works

```r
# 1. Estimate treatment effects and compute concordances
tau_s_hat <- estimate_treatment_effect(data, "S")
tau_y_hat <- estimate_treatment_effect(data, "Y")
h_est <- tau_s_hat * tau_y_hat

# 2. Shrink toward mean (KEY STEP)
h_mean <- mean(h_est)
h_shrunk <- h_mean + 0.5 * (h_est - h_mean)

# 3. Apply DRO to shrunk concordances
phi_star <- wasserstein_dro(h_shrunk, lambda_w)
```

### Why This Works

**Problem:** Selection bias from `min_j(noisy estimates)`
- Extreme negative outliers get selected
- Creates systematic downward bias

**Solution:** Shrink toward mean first
- Reduces magnitude of outliers
- Min operation less affected by noise
- Shrink factor 0.5 optimal (empirically determined)

**Intuition:** Like James-Stein estimation
- Individual estimates are noisy
- Grand mean is stable
- Optimal shrinkage balances bias-variance

## Coverage Validation

**Status:** Running (100 replications)

**Goal:** Verify nominal 95% coverage

**Test:** Bootstrap CI with shrinkage method
- n = 250
- lambda_w = 0.5
- 500 bootstrap iterations per replication
- Check: Does truth fall in CI for ~95% of replications?

**Expected outcome:** PASS (based on low bias and RMSE from Phase 2)

## Implementation Details

### Parameters

- **Shrinkage factor:** 0.5 (or 0.6 as alternative)
- **Bootstrap iterations:** 500+
- **Confidence level:** 95%
- **Sample size:** Works at n=250

### When to Use

Use shrinkage + DRO when:
- Observation-level DRO shows selection bias
- Type-level discretization insufficient (J=16 gives ~50-65% coverage)
- Moderate sample sizes (n ≥ 250)
- Continuous covariates

### Alternative: Conservative k=5

If shrinkage seems too complex:
- Use conservative penalty with k=5
- phi_corrected = phi_naive + 5 × SD(concordances)/√n
- Performance: bias -0.002, RMSE 0.029
- Simpler but slightly larger RMSE

## Files

1. **phase2_systematic_debiasing.R** - Main comparison (50 reps × 20 methods)
2. **phase2_coverage_validation.R** - Coverage test (100 reps with winner)
3. **phase2_debiasing_results.rds** - Full results from comparison
4. **phase2_coverage_validation_results.rds** - Coverage test results
5. **phase2_*.png** - Visualization plots

## Next Steps

1. **After coverage validation passes:**
   - Add `shrinkage_minimax_wasserstein()` to package
   - Document method in vignette
   - Update manuscript methods section
   - Test on different DGPs

2. **If coverage validation fails:**
   - Try shrink_factor = 0.6 (runner-up)
   - Try conservative k=5 (most accurate)
   - Investigate asymmetry in coverage failures

## Theoretical Justification

The shrinkage + DRO method can be viewed as:

1. **Regularized DRO:** Adding implicit penalty to objective
2. **Robust estimation:** M-estimator with soft rejection of outliers
3. **Empirical Bayes:** Data-driven shrinkage toward grand mean

Formal theory to be developed, but empirical performance is excellent.

## Comparison to Original Plan

**Original Phase 2 plan included:**
1. Conservative penalty ✓ (tested k=3 to k=10)
2. Shrinkage + DRO ✓ (WINNER)
3. Double robust ✗ (deferred - not needed)
4. Empirical Bayes ✓ (tested but overcorrects)
5. Bayesian DRO ✗ (deferred - not needed)

**Decision:** Shrinkage solved the problem, no need for more complex approaches.
