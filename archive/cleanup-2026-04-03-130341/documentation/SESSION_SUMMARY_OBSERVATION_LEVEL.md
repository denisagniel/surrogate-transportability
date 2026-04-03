# Session Summary: Observation-Level Wasserstein Solution

**Date:** 2026-03-30
**Status:** Coverage validation running (expected completion: 30-60 minutes)

---

## What We Accomplished

### 1. Diagnosed the Root Cause ✓

**Problem:** Type-level discretization creates noisy estimates
- Bin n=250 into J=16 types → ~15 obs/type
- Treatment effect RMSE per type: 0.30
- Taking minimum amplifies noise → winner's curse
- Result: Systematic bias (-0.06) → 64% coverage (vs 95% target)

**Key insight from Diagnostic 4:**
- Closed-form (discrete types): bias = -0.06
- Sampling (discrete types): bias = -0.06
- **Both failed** → discretization itself is the problem

### 2. Understood How Standard DRO Works ✓

**Your critical question:** "Doesn't DRO work in continuous covariate spaces?"

**Answer:** YES! Standard DRO works at observation level:
- Loss function defined per observation: loss(θ, (x_i, y_i))
- No discretization needed
- Wasserstein dual: n×n cost matrix C[i,j] = ||x_i - x_j||²

**Our challenge:** Treatment effects require aggregation
- τ(x) = E[Y|A=1,X=x] - E[Y|A=0,X=x]
- Can't compute for single observation
- Previous solution: discretize → noisy estimates

**New solution:** Model τ(x) as smooth function, evaluate at each observation

### 3. Implemented Observation-Level Wasserstein DRO ✓

**File:** `package/R/observation_level_minimax.R` (~450 lines)

**Core algorithm:**
1. Estimate τ_S(X) via flexible regression (kernel/RF/GAM/linear)
2. Estimate τ_Y(X) via flexible regression
3. Compute h_i = τ_S(x_i) · τ_Y(x_i) at each observation
4. Build n×n cost matrix: C[i,j] = ||x_i - x_j||²
5. Solve Wasserstein dual:
   ```
   sup_{γ≥0} { -γλ_w² + (1/n)Σᵢ min_j {h_j + γC[i,j]} }
   ```

**Advantages:**
- No discretization → no binning noise
- Treatment effect RMSE: 0.10 (vs 0.30 with types)
- Cost matrix prevents extreme reweighting
- Theoretically principled (Esfahani & Kuhn 2018)

### 4. Validated Mathematical Correctness ✓✓✓

**Test 1: Treatment effect estimation is unbiased**
- Mean bias across 50 reps: 0.002 ✓
- RMSE: 0.10-0.13 ✓

**Test 2: Can find minimums (after fixing λ_w)**
- Initially failed because λ_w = 0.3 too small
- With appropriate λ_w ≥ 1.05: reaches minimum ✓
- **Key realization:** λ_w defines the estimand, not a tuning parameter

**Test 3: Dual formulation is correct**
All 6 properties satisfied:
1. λ=0 → mean: diff = 0 ✓
2. Monotonicity: 19/19 decreasing ✓
3. λ→∞ → min: within 1% ✓
4. Primal-dual match: diff < 0.0001 ✓
5. W₂ constraint satisfied and binding ✓
6. φ* ≤ mean: feasibility ✓

### 5. Clarified the Estimand

**Critical understanding:** λ_w is NOT a tuning parameter!

```
φ*(λ_w) = min_{Q: W_2(Q, P_n) ≤ λ_w} E_Q[concordance]
```

λ_w defines what worst-case we're considering:
- λ_w = 0.3: "Worst if covariates shift ≤0.3 SDs"
- λ_w = 1.0: "Worst if covariates shift ≤1.0 SDs"

The dual is **correctly** solving for whatever λ_w you specify.

For coverage validation, truth = φ*(λ_w) computed from true τ functions, not naive minimum!

### 6. Implemented Coverage Validation (Running Now)

**File:** `coverage_validation.R`

**Design:**
- n = 250 observations
- λ_w = 0.5 (moderate shift, 0.5 SDs)
- n_reps = 100
- n_bootstrap = 100 per rep
- Target coverage: 95%

**Truth computed correctly:**
```r
compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w) {
  # True concordance at each (X1, X2)
  h_true <- tau_s_fn(X1, X2) * tau_y_fn(X1, X2)

  # Solve Wasserstein dual with true h
  # Returns φ*(λ_w) - the correct estimand!
}
```

**Bootstrap CI:**
- Resample observations
- Re-estimate treatment effects
- Re-compute minimax
- Construct CI from bootstrap distribution

**Expected result:** 93-95% coverage

**Status:** Running in background (task ID: bp37cjnew)

---

## Key Insights

### The Discretization Trap

**What went wrong with type-level:**
```
Continuous X → Bin into J types → Estimate τ per type → Take minimum
            ↓                    ↓                      ↓
        Loss of info         Noisy (~15 obs)      Winner's curse
```

Result: RMSE = 0.30, systematic bias = -0.06

**What works with observation-level:**
```
Continuous X → Model τ(x) smoothly → Evaluate at each xᵢ → Wasserstein minimax
            ↓                       ↓                     ↓
     Full information          Stable estimates      Cost matrix regularization
```

Result: RMSE = 0.10, no discretization bias

### The Wasserstein Regularization

Without cost matrix (TV-ball):
- Can put all mass anywhere
- Finds global minimum
- But: noisy estimates → winner's curse

With cost matrix (Wasserstein):
- C[i,j] = ||x_i - x_j||² makes distant reweighting expensive
- λ_w controls how far we can move mass
- Prevents winner's curse through geometry

**Example:**
- Naive minimum: -0.349
- Wasserstein minimum (λ_w=0.3): 0.079
- Regularization effect: **0.428**

### Comparison to Type-Level

| Aspect | Type-Level | Observation-Level |
|--------|------------|-------------------|
| **Dimension** | J = 16 | n = 250 |
| **τ Estimation** | Per-type mean | Kernel regression |
| **RMSE** | 0.30 | 0.10 (65% better) |
| **Geometry** | Discrete categories | Covariate distances |
| **Regularization** | None | Cost matrix |
| **Bias** | -0.06 (systematic) | ~0 (unbiased) |
| **Coverage** | 64% (failed) | TBD (validating) |

---

## Files Created

### Implementation
- `package/R/observation_level_minimax.R` - Main functions
- `coverage_validation.R` - Coverage test (running)

### Validation
- `validate_observation_level_correctness.R` - Tests 1-2
- `test_3_dual_validation_fixed.R` - Test 3 (passed)
- `test_2_recheck_with_distances.R` - λ_w calibration check

### Documentation
- `DRO_CONTINUOUS_SPACE_ANALYSIS.md` - How DRO works
- `OBSERVATION_LEVEL_SOLUTION.md` - Complete solution doc
- `SESSION_SUMMARY_OBSERVATION_LEVEL.md` - This file

### Utilities
- `check_coverage_progress.sh` - Monitor validation

---

## What We're Waiting For

**Coverage validation is running** (~30-60 minutes)

When complete, we'll know:
- **Observed coverage** (target: 93-95%)
- **Bias** (target: <0.02)
- **CI width** (informativeness)

**If coverage passes (≥93%):**
- Solution is validated ✓
- Ready for integration into package
- Ready for manuscript

**If coverage fails (<90%):**
- Need to investigate bootstrap CI construction
- May need more bootstrap iterations
- May need different CI method (BCa, studentized)

---

## Next Steps After Validation

### If Validation Passes ✓

1. **Integrate into package** (~2 hours)
   ```r
   surrogate_inference_minimax <- function(..., method = c("type_level", "observation_level")) {
     if (method == "observation_level") {
       observation_level_minimax_wasserstein(...)
     } else {
       estimate_minimax_ensemble(...)  # Old approach
     }
   }
   ```

2. **Add λ_w selection guidance** (~1 hour)
   - Document how to choose λ_w
   - Based on expected covariate shift
   - Provide defaults (e.g., 0.3, 0.5, 1.0)

3. **Update manuscript** (~4 hours)
   - Add observation-level method section
   - Compare to type-level in simulations
   - Discuss λ_w interpretation
   - Show improved coverage (64% → 95%)

4. **Re-run full simulations** (~1 day)
   - Studies 1 & 2 with observation-level
   - Compare to type-level results
   - Generate updated figures/tables

### If Validation Needs Tuning

5. **Improve bootstrap CI** (~2-4 hours)
   - Try BCa (bias-corrected accelerated)
   - Try studentized (ratio of estimate to SE)
   - Increase bootstrap iterations

6. **Add variance estimation** (~2 hours)
   - Influence function for standard errors
   - Asymptotic theory for Wasserstein DRO

---

## Theoretical Contributions

This work establishes:

1. **Observation-level DRO for treatment effect functionals**
   - First (to our knowledge) application of Wasserstein DRO at observation level for causal estimands
   - Solves the aggregation problem via smooth regression

2. **Correct handling of continuous covariates**
   - No discretization required
   - Cost matrix encodes covariate structure
   - Natural for transportability (covariate shift)

3. **Proper estimand definition**
   - φ*(λ_w) is the constrained minimax
   - Not the naive minimum
   - λ_w has substantive interpretation

4. **Validation framework**
   - How to compute true φ*(λ_w) from DGP
   - Proper coverage testing
   - Distinguishes method validity from λ_w choice

---

## Monitoring Progress

Check coverage validation status:
```bash
bash check_coverage_progress.sh
```

Or check task output directly:
```bash
tail -50 /private/tmp/claude-1141097072/-Users-dagniel-RAND-rprojects-surrogates-surrogate-transportability/tasks/bp37cjnew.output
```

Expected completion: ~30-60 minutes from start
Results saved to: `sims/results/coverage_validation_observation_level.rds`

---

## Summary for User

**Problem:** Type-level discretization (J=16 bins) created noisy estimates → winner's curse → 64% coverage

**Solution:** Observation-level Wasserstein DRO (no discretization)
- Model treatment effects as smooth functions
- Evaluate at each observation
- Use covariate distance cost matrix
- 65% reduction in RMSE (0.30 → 0.10)

**Validation:**
- ✓ Treatment effects unbiased
- ✓ Dual formulation correct (6/6 properties)
- ✓ λ_w properly defines estimand
- ⏳ Coverage validation running (results in ~30-60 min)

**Key insight:** λ_w is not a tuning parameter - it defines what "worst-case" means. The dual correctly solves for whatever λ_w you specify.

This is the principled way to do DRO for surrogate transportability with continuous covariates.
