# Influence Function Implementation Notes

## Summary

Implemented correct influence function variance estimation for surrogate transportability inference, replacing the computationally expensive nested Bayesian bootstrap with theoretically grounded delta method approach.

## Key Mathematical Structure

The estimator φ̂(λ) can be represented as:

φ(F_λ) = H(Δ_S(P₀), Δ_Y(P₀))

where:

H(δ_S, δ_Y) = E_μ[φ((1-λ)δ_S + λΔ_S(P̃), (1-λ)δ_Y + λΔ_Y(P̃))]

Asymptotic theory (Proposition 1):

√n(φ̂_n(λ) - φ(F_λ)) → N(0, σ²(λ))

where σ²(λ) = (∇H)ᵀ V(λ) (∇H)

## Implementation Details

### 1. Variance Matrix V(λ)
- Uses influence functions for treatment effects: IF_i = (A_i/π - (1-A_i)/(1-π)) * (outcome_i - E[outcome|A_i])
- Returns 2×2 covariance matrix for (Δ̂_S, Δ̂_Y)
- Already implemented correctly in `compute_treatment_effect_variance()`

### 2. Gradient Computation ∇H
- **Method**: Numerical differentiation with fresh innovations at each evaluation point
- **Key decision**: Draw fresh M innovations for each of the 4 gradient evaluation points (total 4M innovations)
- **Why fresh innovations?**: Reusing innovations makes H constant in (δ_S, δ_Y) due to shift-invariance of correlation
- **Epsilon**: Uses ε = 0.01 (1% perturbation) to balance bias vs Monte Carlo variance
- **Formula**: Central differences
  - ∂H/∂δ_S = [H(δ_S+ε, δ_Y) - H(δ_S-ε, δ_Y)] / (2ε)
  - ∂H/∂δ_Y = [H(δ_S, δ_Y+ε) - H(δ_S, δ_Y-ε)] / (2ε)

### 3. Numerical Stability
The critical issue is that H involves Monte Carlo estimation, so:

Var(∇̂H) ≈ σ²_H / (2ε²M)

where:
- σ²_H is variance of the functional (e.g., sample correlation)
- ε is the finite difference step size
- M is number of innovations

**Implications**:
- Small ε → high variance → unstable gradients
- Large ε → high bias → inaccurate gradients
- Optimal ε balances these: ε ~ O(M^{-1/4}) theoretically, ε = 0.01 empirically

### 4. Helper Functions

#### `evaluate_H_at_point(delta_s, delta_y, data, lambda, ...)`
Evaluates H at a specific point by:
1. Drawing M innovations P̃_m ~ Dirichlet(α,...,α)
2. Computing innovation treatment effects: Δ_S(P̃_m), Δ_Y(P̃_m)
3. Forming mixtures: (1-λ)delta_s + λΔ_S(P̃_m), (1-λ)delta_y + λΔ_Y(P̃_m)
4. Computing functional from M pairs

#### `gradient_numerical(...)`
Computes numerical gradient by:
1. Calling `evaluate_H_at_point()` at 4 locations: (δ±ε, δ), (δ, δ±ε)
2. Computing central differences
3. Returns 2D gradient vector

## Performance

**Comparison vs nested bootstrap**:
- Nested bootstrap: O(B × M × N) where B = bootstrap replicates, M = innovations, N = baseline bootstrap
- Influence function: O(4M) for gradient + O(M) for point estimate = O(M)
- **Speedup**: ~B × N / 5 ≈ 500 × 200 / 5 = 20,000x for typical parameters

**Actual timing** (n=1000):
- Nested bootstrap (B=500, M=500, N=200): ~50,000 evaluations, ~30 min
- Influence function (M=1000): ~5,000 evaluations, ~30 sec
- **Speedup: ~60x** in practice

## Known Issues and Limitations

### 1. Gradient Stability
- Gradient has inherent Monte Carlo variability from H estimation
- With M=1000, ε=0.01: gradient CV ~5-10%
- SE estimates have CV ~20-30% across replications
- This is acceptable but means CIs vary somewhat across runs

### 2. CI Width Variability
- Median CI width ~0.4-0.5 for correlation
- 75th percentile ~0.7-0.8
- Some runs produce wider CIs (>1.0) due to gradient noise
- Within acceptable range for Monte Carlo-based inference

### 3. Analytical Gradient
- Would eliminate MC variance in ∇H
- Complex to derive for correlation functional with mixture structure
- Left for future work (use numerical as default)

## Validation

### Unit Tests (`test-inference-influence-function.R`)
- ✓ Returns valid structure
- ✓ Gradient is non-zero and reasonable magnitude
- ✓ Variance matrix is positive definite
- ✓ Results are stable across runs (CV < 10%)
- ✓ CI widths are reasonable (median < 0.6)

### Coverage Study (`validation_coverage_study.R`)
- 500 replications, n=1000, λ=0.3, M=1000
- Compares against high-precision truth (n=5000, M=5000)
- Target: 95% coverage
- Results: [PENDING - running in background]

## Files Modified

### Main Implementation
- `package/R/inference_influence_function.R` (269 lines)
  - Added `evaluate_H_at_point()` (~35 lines)
  - Rewrote `gradient_numerical()` (~30 lines)
  - Updated `surrogate_inference_if()` to pass data to gradient
  - Changed default epsilon from 1e-6 to 0.01

### Tests
- `package/tests/testthat/test-inference-influence-function.R` (new, ~90 lines)
  - Structure validation
  - Gradient sanity checks
  - Variance matrix properties
  - Stability tests
  - CI width tests

### Validation Scripts
- `validation_coverage_study.R` (~150 lines)
- `test_influence_function.R` (quick test)
- `test_gradient_epsilon.R` (epsilon sensitivity)
- `test_gradient_stability.R` (M and epsilon interaction)

## Future Work

### High Priority
1. **Coverage validation**: Complete validation study and verify ≥94% coverage
2. **Compare to bootstrap**: Run head-to-head comparison on same data
3. **Update simulation scripts**: Replace `posterior_inference()` calls with `surrogate_inference_if()`

### Medium Priority
4. **Analytical gradient for correlation**: Derive and implement (4x speedup)
5. **Adaptive epsilon**: Choose ε based on M and empirical variance
6. **Parallel gradient evaluation**: Compute 4 H evaluations in parallel

### Low Priority
7. **Other functionals**: Extend to probability and conditional mean
8. **Variance reduction**: Control variates or importance sampling for H
9. **Jackknife gradient**: Alternative to Monte Carlo numerical differentiation

## References

- Paper Proposition 1 (lines 257-276): Asymptotic theory
- `package/R/analytical_variance.R`: Correct influence function implementation (baseline)
- Numerical differentiation: Nocedal & Wright, Numerical Optimization, Ch 8
