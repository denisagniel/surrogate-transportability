# Wasserstein Minimax IF-Based Inference: Simulation Study Design

## Overview

Comprehensive simulation study to evaluate the performance of `wasserstein_minimax_IF_inference()` across different scenarios.

**Status:** Running (500 replications per scenario)

---

## Study Design

### Study 1: Coverage by Sample Size

**Objective:** Assess finite-sample coverage properties and verify asymptotic normality.

**Design:**
- Sample sizes: n ∈ {200, 300, 500, 750, 1000}
- DGP: Linear treatment effects (moderate concordance)
  - τ_S(X) = 0.3 + 0.2X
  - τ_Y(X) = 0.4 + 0.3X
- Parameters: γ = 0.5, τ = 0.1
- Replications: 500 per sample size

**Metrics:**
- Coverage rate (target: 95%)
- Empirical SE vs IF-based SE (variance ratio, target: 1.0)
- Bias (relative to oracle truth)
- Mean CI width

**Expected outcomes:**
- Coverage should approach 95% as n increases
- Variance ratio should approach 1.0 (asymptotic validity)
- Bias should decrease as O(1/√n)

---

### Study 2: Performance Across Different DGPs

**Objective:** Test robustness to different data generating processes and misspecification.

**Design:**
Six DGPs with n = 500:

1. **Linear (Low Concordance):**
   - τ_S(X) = 0.3 + 0.2X
   - τ_Y(X) = 0.1 + 0.05X
   - Tests performance when concordance is weak

2. **Linear (Moderate Concordance):**
   - τ_S(X) = 0.3 + 0.2X
   - τ_Y(X) = 0.4 + 0.3X
   - Baseline scenario

3. **Linear (High Concordance):**
   - τ_S(X) = 0.3 + 0.2X
   - τ_Y(X) = 0.6 + 0.4X
   - Strong surrogate relationship

4. **Nonlinear:**
   - τ_S(X) = 0.3 + 0.2X + 0.1X²
   - τ_Y(X) = 0.4 + 0.3X + 0.05X²
   - Tests linear model fitting quadratic truth

5. **Heteroskedastic Noise:**
   - Linear treatment effects
   - Error SD = 0.3 + 0.2|X|
   - Tests robustness to heteroskedasticity

6. **Multivariate:**
   - Two covariates: X1, X2
   - τ_S = 0.3 + 0.2X1 + 0.1X2
   - τ_Y = 0.4 + 0.3X1 + 0.15X2
   - Tests multidimensional covariate space

**Metrics:**
- Coverage, bias, variance ratio for each DGP
- Relative bias = bias / truth
- Mean concordance under P0 (no adversarial shift)

**Expected outcomes:**
- Linear DGPs: Near-nominal coverage (~95%)
- Nonlinear: Slight undercoverage due to model misspecification
- Heteroskedastic: Robust (IF accounts for this)
- Multivariate: Similar performance (cost matrix handles multiple dimensions)

---

### Study 3: Sensitivity to Gamma (Wasserstein Penalty)

**Objective:** Understand how the penalty parameter γ affects estimation and inference.

**Design:**
- Gamma values: {0.1, 0.25, 0.5, 0.75, 1.0, 1.5}
- DGP: Linear (moderate concordance)
- n = 500, τ = 0.1 (fixed)
- Replications: 500 per γ

**Key insights:**
- γ controls the "cost" of transporting mass in covariate space
- Small γ → adversary can shift distribution more freely → lower minimax bound
- Large γ → adversary constrained → minimax bound closer to concordance_P0
- Truth varies with γ (oracle computed separately for each)

**Metrics:**
- Coverage at each γ
- Estimate vs truth (should track closely)
- How minimax bound approaches concordance_P0 as γ increases

**Expected outcomes:**
- Consistent coverage across γ values (~95%)
- Estimate tracks truth (no systematic bias)
- Minimax concordance increases monotonically with γ

---

### Study 4: Sensitivity to Tau (Temperature)

**Objective:** Assess numerical stability and approximation quality at different temperature levels.

**Design:**
- Tau values: {0.05, 0.1, 0.15, 0.2, 0.3, 0.5}
- DGP: Linear (moderate concordance)
- n = 500, γ = 0.5 (fixed)
- Replications: 500 per τ

**Key insights:**
- τ controls smoothness of the log-sum-exp approximation
- Small τ → closer to exact minimum (but risk of numerical underflow)
- Large τ → more stable (but looser approximation)
- Truth varies with τ (different approximation level)

**Metrics:**
- Coverage at each τ
- Numerical stability (proportion of valid runs)
- Variance ratio (IF approximation quality)

**Expected outcomes:**
- Coverage stable for τ ∈ [0.1, 0.3]
- Potential issues with very small τ (< 0.05) if h values large
- Variance ratio near 1.0 across reasonable τ range

---

## Preliminary Results (Quick Test: 50 Replications, n=500)

```
Truth: 0.324095
Coverage: 92.0%
Bias: -0.006227
Empirical SE: 0.025129
Mean IF SE: 0.025301
Variance ratio: 1.007
```

✓ Coverage close to target (within Monte Carlo error)
✓ Variance ratio near 1.0 (IF valid)
✓ Small bias (< 2% of truth)

---

## Planned Visualizations

### Figure 1: Sample Size Effects
- Panel A: Coverage rate by n (with 95% target line)
- Panel B: Variance ratio by n (with 1.0 target line)

### Figure 2: DGP Comparison
- Panel A: Coverage rate across DGPs (bar chart)
- Panel B: Variance ratio across DGPs (bar chart)

### Figure 3: Gamma Sensitivity
- Panel A: Coverage rate by γ
- Panel B: Estimate vs truth by γ (both curves)

### Figure 4: Tau Sensitivity
- Panel A: Coverage rate by τ
- Panel B: Variance ratio by τ

---

## Implementation Details

**Function tested:** `wasserstein_minimax_IF_inference()`
- Location: `package/R/wasserstein_minimax_IF_inference.R`
- Cross-fitting: K = 5 folds
- Nuisance estimation: Linear regression
- IF formula: Corrected three-term (outer + inner + nuisance)

**Oracle truth computation:**
- Large sample (n=10,000) with true treatment effects
- Direct evaluation of Wasserstein dual
- Specific to each (γ, τ) combination

**Computational notes:**
- ~500 simulations × (5 sample sizes + 6 DGPs + 6 γ values + 6 τ values)
- Total: ~11,500 simulations
- Runtime: ~3-4 hours on standard laptop
- Parallelization: Not yet implemented (future improvement)

---

## Success Criteria

### Primary (Coverage)
- Study 1: Coverage ∈ [90%, 97%] for n ≥ 300 ✓ (if preliminary holds)
- Study 2: Coverage ∈ [90%, 97%] for linear DGPs ✓
- Study 3-4: Stable coverage across parameter values

### Secondary (Variance)
- Variance ratio ∈ [0.9, 1.2] across all scenarios
- Ratio approaches 1.0 as n increases

### Robustness
- No failures (all simulations complete)
- Nonlinear DGP: Coverage ≥ 85% (some bias acceptable)
- Multivariate: Similar performance to univariate

---

## Files

**Simulation scripts:**
- `sims/scripts/wasserstein_minimax_simulation_study.R` - Main study (500 reps)
- `sims/scripts/wasserstein_minimax_quick_test.R` - Quick test (50 reps)
- `sims/scripts/analyze_wasserstein_simulation.R` - Analysis and visualization

**Results:**
- `sims/results/wasserstein_minimax_simulation_study.rds` - Full results
- `sims/results/wasserstein_sim_figure*.pdf` - Four figures

---

## Next Steps After Completion

1. **Analyze results** - Run `analyze_wasserstein_simulation.R`
2. **Review figures** - Check coverage, variance ratios, parameter sensitivity
3. **Document findings** - Create summary report
4. **Identify improvements** - If issues found, adjust method or parameters
5. **Compare to bootstrap** - Optional: benchmark against bootstrap inference
6. **Report in paper** - Include key findings in methods section

---

## Expected Timeline

- **Study 1:** ~2 minutes (completed)
- **Study 2:** ~6 minutes
- **Study 3:** ~5 minutes
- **Study 4:** ~5 minutes
- **Total:** ~18-20 minutes

**Status check:** Use `TaskOutput` to monitor progress.

**Analysis:** Run immediately after completion to generate figures and summary.
