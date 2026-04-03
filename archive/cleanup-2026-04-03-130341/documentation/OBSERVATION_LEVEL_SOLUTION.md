# Observation-Level Wasserstein Solution (No Discretization)

**Date:** 2026-03-30
**Status:** Implemented and tested

---

## Problem Diagnosis

**Root cause of 64% coverage failure:**

Discretizing continuous covariates into J=16 types created systematic bias:
- With n=250, each type has ~15 observations
- Type-level treatment effect estimates have RMSE ≈ 0.3
- Taking minimum across types amplifies noise ("winner's curse")
- Result: systematic underestimation → poor coverage

**Key insight from diagnostics:**
- Diagnostic 4 showed closed-form (discretized) has bias -0.06
- Sampling over discrete types also failed (not accidental regularization)
- Problem: **We shouldn't discretize at all**

---

## How Standard DRO Handles Continuous Spaces

Standard DRO doesn't discretize because:
- Loss function is defined at **observation level**
- Each (x_i, y_i) has a loss
- No aggregation needed

**Our challenge:** Treatment effects require aggregation:
- τ(x) = E[Y|A=1,X=x] - E[Y|A=0,X=x]
- Can't compute for single observation
- Need groups or regression

---

## Solution: Treatment Effect Regression + Observation-Level Wasserstein

### Algorithm

1. **Estimate τ_S(X) via flexible regression** (kernel, random forest, GAM)
   - Model E[S|A,X] as smooth function
   - τ_S(x_i) at each observation

2. **Estimate τ_Y(X) similarly**

3. **Compute concordance at each observation:**
   h_i = τ_S(x_i) · τ_Y(x_i)

4. **Build n×n cost matrix:**
   C[i,j] = ||x_i - x_j||²

5. **Solve Wasserstein DRO dual:**
   ```
   sup_{γ≥0} { -γλ_w² + (1/n)Σᵢ min_j {h_j + γC[i,j]} }
   ```

### Key Advantages

**vs Type-Level Discretization:**
- ✅ No binning → no discretization noise
- ✅ Treatment effects from smooth regression (RMSE: 0.12 vs 0.30)
- ✅ Preserves full covariate information
- ✅ Natural for continuous covariate spaces

**Wasserstein Regularization:**
- Cost matrix C[i,j] = ||x_i - x_j||² prevents extreme reweighting
- Can't put all mass on worst observation (too far away → high cost)
- Example: naive min = -0.349, Wasserstein min = 0.079
- **Winner's curse eliminated by geometry**

---

## Implementation

### New Function: `observation_level_minimax_wasserstein()`

**Location:** `package/R/observation_level_minimax.R`

**Usage:**
```r
result <- observation_level_minimax_wasserstein(
  data = mydata,
  covariates = c("age", "sex", "baseline_health"),
  lambda_w = 0.3,
  tau_method = "kernel",  # or "rf", "gam", "linear"
  cross_fit = TRUE,        # recommended
  scale_covariates = TRUE
)

# Minimax concordance estimate
phi_star <- result$phi_star

# Treatment effect estimates at each observation
tau_s_hat <- result$tau_s_hat
tau_y_hat <- result$tau_y_hat
```

**Methods for estimating τ(X):**

1. **Kernel (default):** Local linear regression with automatic bandwidth
2. **Random Forest:** Separate forests for E[Y|A=1,X] and E[Y|A=0,X]
3. **GAM:** Smooth splines via mgcv package
4. **Linear:** E[Y|A,X] = α + τ·A + X'β (assumes constant effects)

**Cross-fitting (recommended):**
- Split data into K folds
- Fit on K-1 folds, predict on held-out fold
- Avoids overfitting in τ(x) estimates
- Critical for valid inference downstream

---

## Test Results

### Test Setup
- n = 500 observations
- True treatment effects: τ_S(X) = 0.3 + 0.2X₁ - 0.1X₂
- True treatment effects: τ_Y(X) = 0.4 + 0.3X₁ + 0.1X₂
- lambda_w = 0.3

### Results

**Treatment Effect Estimation Quality:**
```
tau_S: RMSE = 0.115 | Cor = 0.871
tau_Y: RMSE = 0.164 | Cor = 0.885
Concordance: RMSE = 0.103 | Cor = 0.855
```

**Compare to type-level discretization (Diagnostic 4):**
```
Type-level RMSE: ~0.30 (concordance)
Observation-level RMSE: 0.103
Improvement: 65% reduction in error
```

**Wasserstein Regularization:**
```
Mean concordance:       0.178
Naive minimum:         -0.349
Wasserstein minimum:    0.079

Regularization effect:  0.428 (prevents winner's curse!)
```

**Pattern Across lambda_w:**
| lambda_w | phi_star | Interpretation |
|----------|----------|----------------|
| 0.1      | 0.157    | Tight constraint, close to mean |
| 0.3      | 0.101    | Moderate regularization |
| 0.5      | 0.054    | Looser constraint |
| 1.0      | -0.045   | Very loose, approaching naive min |

As lambda_w increases, constraint loosens → lower minimax (correct pattern).

---

## Next Steps

### 1. Validate with Coverage Diagnostic (HIGH PRIORITY)

Run coverage test on simulated data:
```r
# Test if observation-level achieves 93-95% coverage
n_reps <- 100
lambda_w <- 0.3

for (rep in 1:n_reps) {
  dgp <- generate_data_with_true_types(...)

  # True minimax under true parameters
  truth <- compute_true_minimax(dgp)

  # Observation-level estimate with bootstrap CI
  result <- observation_level_minimax_wasserstein_with_bootstrap(
    data = dgp$data,
    covariates = c("X"),
    lambda_w = lambda_w,
    n_bootstrap = 100
  )

  covered <- (truth >= result$ci_lower & truth <= result$ci_upper)
}

mean(covered)  # Should be ~0.95
```

**Expected result:** 93-95% coverage (vs 64% for type-level, 8% for ensemble).

### 2. Implement Bootstrap CI

Add bootstrap wrapper:
```r
observation_level_minimax_wasserstein_with_bootstrap <- function(...) {
  # Bootstrap observations
  # For each bootstrap sample:
  #   - Re-estimate tau_S(X), tau_Y(X)
  #   - Compute minimax
  # Construct CI from bootstrap distribution
}
```

### 3. Compare to Wasserstein Type-Level (Diagnostic 5)

Diagnostic 5 is currently running. Will show:
- Does type-level Wasserstein work better than type-level TV-ball?
- If yes: Wasserstein geometry is helping even with discretization
- If no: Need observation-level approach (what we built)

### 4. Integration into Package

Replace or augment `surrogate_inference_minimax()`:
```r
surrogate_inference_minimax <- function(...,
                                         use_observation_level = TRUE,
                                         tau_estimation_method = "kernel") {

  if (use_observation_level) {
    # New approach (no discretization)
    observation_level_minimax_wasserstein(...)
  } else {
    # Old approach (discretization)
    estimate_minimax_ensemble(...)
  }
}
```

---

## Theoretical Justification

### Why This is Principled

**DRO dual for Wasserstein balls (Esfahani & Kuhn 2018):**

For linear functional h(ω):
```
min_{Q: W_2(Q,P_n)≤λ} E_Q[h]  has dual  sup_{γ≥0} g(γ)
```

where:
```
g(γ) = -γλ² + E_Pn[min_{ω'} {h(ω') + γc(ω, ω')}]
```

**Our implementation:**
- h(ω) = τ_S(x) · τ_Y(x) (concordance functional)
- c(ω, ω') = ||x - x'||² (covariate distance)
- Solve 1D optimization over γ ≥ 0
- Exact dual (no approximation)

**Key properties:**
- Strong duality holds (Esfahani & Kuhn Theorem 4.1)
- O(n²) per γ evaluation
- O(n² log(1/ε)) total (fast!)
- No discretization error

### Comparison to Prior Approaches

| Approach | n-dim | Discretization | Noise | Geometry |
|----------|-------|----------------|-------|----------|
| Type-level TV | J=16 | Yes | High (RMSE~0.3) | Discrete (no structure) |
| Type-level Wasserstein | J=16 | Yes | High | Preserves some structure via cost |
| **Observation-level Wasserstein** | **n=250** | **No** | **Low (RMSE~0.1)** | **Full covariate structure** |

---

## Files

**Implementation:**
- `package/R/observation_level_minimax.R` - Main functions
- `test_observation_level.R` - Validation tests
- `DRO_CONTINUOUS_SPACE_ANALYSIS.md` - Theoretical background

**Next:**
- Coverage validation script
- Bootstrap CI implementation
- Integration with main inference function

---

## Summary

**Problem:** Discretization creates noisy estimates → systematic bias → poor coverage

**Solution:** Work at observation level like standard DRO:
1. Model treatment effects as smooth functions: τ(X)
2. Evaluate at each observation: h_i = τ_S(x_i) · τ_Y(x_i)
3. Use Wasserstein dual with covariate distance cost matrix
4. No discretization → no discretization noise

**Results:** 65% reduction in RMSE, massive regularization effect (0.428), correct DRO behavior across lambda_w values.

**Status:** Implemented and tested. Ready for coverage validation and integration.
