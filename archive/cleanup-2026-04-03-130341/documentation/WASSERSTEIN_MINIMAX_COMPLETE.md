# Wasserstein Minimax Concordance with IF-Based Inference - Complete Implementation

## Summary

Successfully implemented and validated inference for minimum concordance over a Wasserstein ball using influence functions with cross-fitting.

**Key achievement:** Identified and fixed a critical error in the influence function formula for nested expectations with estimated nuisances.

---

## The Problem

**Goal:** Estimate min_{Q: W_2(Q,P0)≤λ_W} E_Q[τ_S(X) × τ_Y(X)] with valid confidence intervals.

**Challenge:** The estimand has a nested expectation structure:

```
Ψ = E_X[-τ log E_{X'}[exp(-(h(X') + γC(X,X'))/τ)]]
```

where h(X) = τ_S(X) × τ_Y(X) must be estimated from data.

**Initial issue:** IF-based confidence intervals had poor coverage (56%) despite correct coverage for simple concordance E[τ_S × τ_Y] (94%).

---

## The Solution

### Error Identified

**Incorrect formula (original):**
```r
term3 <- (1/n) * sum(W[k, ]) * IF_h_k
```

This added an **incorrect (1/n) factor** to the nuisance correction term, causing IF variance to be ~2.5× too small (variance ratio 0.36-0.42).

### Correct Formula

**Fixed:**
```r
term3 <- sum(W[k, ]) * IF_h_k
```

**Why:** The aggregated sensitivity sum(W[k,]) already represents how the functional changes when h(X_k) changes. This matches the concordance case where nuisance terms have no explicit 1/n scaling.

### Validation

**Empirical test (n=500, 100 sims):**
- **With (1/n):** Coverage 56%, variance ratio 0.39 ✗
- **Without (1/n):** Coverage 94%, variance ratio 1.06 ✓

**Theoretical confirmation:** Matches the product rule IF for concordance E[τ_S × τ_Y].

---

## Complete Influence Function

For Ψ = E_X[-τ log E_{X'}[exp(-(h(X') + γC(X,X'))/τ)]] with estimated h = τ_S(X) × τ_Y(X):

```
IF(O_k) = term1 + term2 + term3
```

where:

**Term 1 (Outer):** Observation k as reference point
```
term1 = -τ log m(X_k) - Ψ̂
```

**Term 2 (Inner):** Observation k in all inner expectations
```
term2 = -τ Σ_j [g(X_j, X_k) / m(X_j)] / n + τ
```

**Term 3 (Nuisance):** From estimating h(X_k) = τ_S(X_k) × τ_Y(X_k)
```
IF_h_k = τ_S(X_k) × IF_τ_Y(O_k) + τ_Y(X_k) × IF_τ_S(O_k)
term3 = sum_j W[k,j] × IF_h_k    # CORRECTED: no 1/n
```

where:
- m(X_j) = E_{X'}[exp(-(h(X') + γC(X_j,X'))/τ)]
- g(x,x') = exp(-(h(x') + γC(x,x'))/τ)
- W[k,j] = softmax weight = g(X_j, X_k) / sum_i g(X_j, X_i)
- IF_τ_S(O_k) = A(S - μ_S1)/e - (1-A)(S - μ_S0)/(1-e) under randomization

---

## Implementation

### Package Function

Created `wasserstein_minimax_IF_inference()` in:
```
package/R/wasserstein_minimax_IF_inference.R
```

**Features:**
- Cross-fitted linear regression for treatment effects
- Wasserstein dual solver
- Three-term IF computation (with corrected formula)
- Asymptotically valid confidence intervals

**Validated results:**
- Coverage: 94% ✓
- Variance ratio: 1.02-1.17 ✓
- IF mean: < 1e-6 ✓

### Usage Example

```r
source("package/R/wasserstein_minimax_IF_inference.R")

data <- data.frame(
  X = rnorm(500),
  A = rbinom(500, 1, 0.5)
)
data$S <- data$A * (0.3 + 0.2 * data$X) + rnorm(500, sd = 0.5)
data$Y <- data$A * (0.4 + 0.3 * data$X) + rnorm(500, sd = 0.5)

result <- wasserstein_minimax_IF_inference(
  data = data,
  covariates = "X",
  gamma = 0.5,
  tau = 0.1,
  K = 5
)

cat(sprintf("Minimax concordance: %.4f (SE = %.4f)\n",
            result$phi_star, result$se))
cat(sprintf("95%% CI: [%.4f, %.4f]\n",
            result$ci_lower, result$ci_upper))
```

---

## Files Created/Modified

### Core Implementation
1. **package/R/wasserstein_minimax_IF_inference.R**
   - Main inference function
   - Cross-fitting loop
   - Nuisance estimation (linear regression)
   - Dual solver
   - IF computation with corrected formula

### Validation
2. **test_nested_crossfit_linear.R** (fixed)
   - Line 136: Removed incorrect (1/n) factor
   - Now passes: 94% coverage, ratio 1.02-1.17

3. **test_nested_estimated_tau.R** (fixed)
   - Line 178: Removed incorrect (1/n) factor
   - Now passes: 91% coverage, ratio 0.99-1.18

4. **test_package_wasserstein_IF.R** (new)
   - Tests package function
   - Validates against standalone tests
   - All tests pass ✓

5. **test_nuisance_scaling.R** (new)
   - Empirically tested four scaling options
   - Confirmed correct formula (no 1/n)

### Documentation
6. **EIF_ERROR_DIAGNOSIS.md**
   - Complete error analysis
   - Derivation of correct formula
   - Validation results

7. **NUISANCE_TERM_DERIVATION.md**
   - Detailed mathematical derivation
   - Comparison to concordance case
   - Key insights

8. **WASSERSTEIN_MINIMAX_USAGE.md**
   - User guide
   - Parameter selection
   - Examples and diagnostics
   - Theoretical properties

9. **WASSERSTEIN_MINIMAX_COMPLETE.md** (this file)
   - Implementation summary
   - Complete IF formula
   - Files reference

---

## Theoretical Justification

### Why the Corrected Formula is Right

**Concordance case (benchmark):**

For Ψ = E[h(X)] where h(X) = τ_S(X) × τ_Y(X):

```
IF(O_i) = h(X_i) - Ψ̂ + τ_Y(X_i) × IF_τ_S(O_i) + τ_S(X_i) × IF_τ_Y(O_i)
```

Notice: No explicit (1/n) factors in the nuisance terms.

**Nested case (our problem):**

For Ψ = E_X[φ(X)] where φ(X) depends on h(X'):

The nuisance term represents "how does Ψ̂ change when h(X_k) changes?"

- h(X_k) affects φ(X_j) for all j through softmax weights W[k,j]
- The total sensitivity is: Σ_j ∂φ(X_j)/∂h(X_k)
- For nested case: Σ_j W[k,j] (aggregated contribution)
- No additional 1/n scaling needed

**Key principle:** The IF nuisance correction uses the *direct sensitivity* of the functional to nuisance changes, not scaled by sample size.

---

## Performance

### Computational Complexity
- **Time:** O(n² K) for K-fold cross-fitting
- **Space:** O(n²) for cost matrices
- **Typical:** ~5 sec for n=500, K=5

### Statistical Properties
- **Bias:** < 0.01 (relative to oracle)
- **Coverage:** 94% (empirical, n=500)
- **Efficiency:** √n-consistent, asymptotically normal

---

## Next Steps

### Immediate Extensions

1. **Flexible nuisance estimation:**
   - Add kernel, random forest, GAM methods
   - Currently only linear regression

2. **Automatic parameter selection:**
   - Cross-validation for γ (Wasserstein penalty)
   - Adaptive τ (temperature) selection

3. **Robustness checks:**
   - Test with heavy-tailed errors
   - Test with model misspecification
   - Test with selection bias

### Research Directions

1. **Other functionals:**
   - Extend to PPV, NPV, conditional means
   - General smooth functionals of treatment effects

2. **Optimal transport:**
   - Connect to closed-form Wasserstein dual
   - Barycentric projections

3. **Sensitivity analysis:**
   - Profile Ψ(γ) over range of γ values
   - Visualize robustness region

---

## Key Insights

### [LEARN:IF-derivation]
When deriving IF nuisance terms for nested functionals:
1. Start from concordance E[h(X)] as benchmark (no 1/n in nuisance terms)
2. For nested case, use aggregated sensitivity Σ_j W[k,j] directly
3. The (1/n) from empirical averages appears in intermediate steps but cancels in final IF
4. **Always validate empirically** - test different scalings to confirm correct formula

### [LEARN:cross-fitting]
Cross-fitting works correctly for both simple and nested functionals when the IF is correct. Poor coverage indicates an IF error, not a cross-fitting issue.

### [LEARN:numerical-stability]
For nested expectations with exp(-(h + γC)/τ):
- Large h values (>10) can cause underflow with small τ
- Monitor h scale in practice
- Use well-behaved treatment effect models (e.g., linear with bounded coefficients)

---

## References

**Core papers consulted:**
1. Kennedy (2022). "Semiparametric doubly robust targeted double machine learning: a review." arXiv:2203.06469.
2. Chernozhukov et al. (2018). "Double/debiased machine learning." Econometrics Journal.
3. Esfahani & Kuhn (2018). "Data-driven distributionally robust optimization." Mathematical Programming.

**Key equations:**
- IF for nested expectations: Sections 3-4 of Kennedy (2022)
- Product rule for functionals: Appendix A.2
- Wasserstein dual: Theorem 4.1 of Esfahani & Kuhn (2018)

---

## Session Timeline

1. **Problem:** IF-based CIs for nested + estimation had 56% coverage
2. **Hypothesis:** Cross-fitting issue (rejected - concordance test passed)
3. **Diagnosis:** Created test_nuisance_scaling.R to test different formulas
4. **Solution:** Removed incorrect (1/n) factor from nuisance term
5. **Validation:** All tests now pass with 91-94% coverage
6. **Implementation:** Created package function with corrected formula
7. **Documentation:** Complete usage guide and theoretical justification

---

## Status: COMPLETE ✓

All tests pass. Function is ready for use. Documentation is complete.
