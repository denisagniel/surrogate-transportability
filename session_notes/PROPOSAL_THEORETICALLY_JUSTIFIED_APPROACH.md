# Proposal: Theoretically Justified Innovation Distribution

## Executive Summary

Based on theoretical analysis of the methods paper and empirical validation, we propose:

1. **Primary approach**: Type-level innovations when types are known/observable
2. **Fallback**: Covariate-level innovations with adaptive binning when types are latent
3. **Variance calibration**: None needed for type-level; moderate calibration (exponent ~1.2-1.5) for covariate-level
4. **Known limitation**: Large K (≥50) with weak correlation is fundamentally challenging

## Theoretical Justification

### The Estimand

From methods paper: φ(F_λ) where F_λ is a random distribution
- F_λ = (1-λ)P₀ + λP̃
- P̃ ~ μ = Dirichlet(1,...,1) over k dimensions
- k = |Ω| (number of cells in partition of outcome space)

**Key insight**: The choice of k determines what we're estimating!

### What is the "Right" k?

**From transportability perspective**:
- Future studies differ in their POPULATION COMPOSITION
- Populations are characterized by types/subgroups
- Treatment effects vary by type
- Therefore: k should equal the number of TYPES

**From the paper**:
- "Data naturally partitions into cells" (deliberately vague)
- Could be types, covariate bins, or observations
- Choice determines the support of μ

**Our conclusion**: k = K (types) is theoretically correct, but K may not be observed.

## Empirical Evidence

### What Works

| Scenario | K | Approach | J/n | Correlation | Variance | Assessment |
|----------|---|----------|-----|-------------|----------|------------|
| K=4 | 4 | Type-level | 4 | 100% | 100% | ✓ Perfect |
| K=4 | 4 | Covariate (J=9) | 9 | 98% | 163% | ✓ Excellent correlation, high variance |
| K=4 | 4 | Obs-level | 1000 | 92% | 80% | ✗ Both too low |
| K=10 | 10 | Type-level | 10 | 100% | 100% | ✓ Perfect |
| K=10 | 10 | Covariate (J=9) | 9 | 100% | 230% | ~ Good correlation, very high variance |
| K=20 | 20 | Type-level | 20 | 100% | 100% | ✓ Perfect |
| K=20 | 20 | Covariate (J=9) | 9 | 98% | 304% | ~ Good correlation, extreme variance |
| K=100 | 100 | Type-level | 100 | 64% | ??? | ✗ Weak signal + small groups |
| K=100 | 100 | Covariate (J=25) | 25 | 65% | 220% | ✗ Same failure |

### Key Patterns

1. **Type-level is "correct"**: Always 100% recovery for K ≤ 20
2. **Covariate-level works when J ≥ K**: Correlation excellent but variance too high
3. **Observation-level fails for small K**: Underestimates both correlation and variance
4. **Large K + weak ρ is hard**: Both approaches fail at K=100 (fundamental, not implementation)

## Proposed Implementation

### Hierarchy of Approaches

```r
surrogate_inference_if <- function(data, lambda, ...,
                                   type_variable = NULL,
                                   covariates = NULL,
                                   n_bins = "auto") {

  # APPROACH 1: Type-level innovations (if types known)
  if (!is.null(type_variable)) {
    K <- length(unique(data[[type_variable]]))
    innovations <- rdirichlet(M, rep(alpha, K))

    # Map type-level innovations to observation weights
    for (m in 1:M) {
      type_weights_m <- innovations[m, ]
      obs_weights <- map_types_to_obs(data, type_variable, type_weights_m, lambda)
      # Bootstrap with these weights...
    }

    # NO VARIANCE CALIBRATION NEEDED - this is the correct target
    return(result)
  }

  # APPROACH 2: Covariate-level innovations (if covariates provided)
  if (!is.null(covariates)) {
    X <- as.matrix(data[, covariates])

    # Choose J adaptively
    if (n_bins == "auto") {
      J <- choose_bins_adaptively(n, X)
    } else {
      covariate_bins <- discretize_covariates(X, n_bins_per_covariate = n_bins)
      J <- length(unique(covariate_bins))
    }

    innovations <- rdirichlet(M, rep(alpha_calibrated, J))

    # Variance calibration for covariate-level
    # Estimate inflation from cross-validation
    cv_het <- estimate_cv_heterogeneity(data, covariate_bins)
    alpha_calibrated <- 1 / cv_het$inflation_factor^(1.3)  # Moderate calibration

    # Bootstrap with covariate-bin weights...

    return(result)
  }

  # APPROACH 3: Observation-level (fallback, conservative)
  warning("No type or covariate information provided. Using observation-level innovations (may underestimate variation for heterogeneous populations).")

  innovations <- rdirichlet(M, rep(1, n))
  # Bootstrap with observation weights...

  return(result)
}
```

### Adaptive Bin Selection

For covariate-level approach, choose J to balance:
- **Too small J**: Loses heterogeneity (K=100 with J=25)
- **Too large J**: Each bin has few observations, bootstrap noise

**Proposed rule**:
```r
choose_bins_adaptively <- function(n, X) {
  p <- ncol(X)  # Number of covariates

  # Heuristic: J ~ min(K_hat, n/10, 5^p)
  # where K_hat is estimated number of types

  K_hat <- estimate_n_types(X)  # e.g., via BIC on mixture model

  # Maximum bins from p covariates with 3-5 bins each
  max_bins_possible <- min(5^p, n/10)

  # Choose smaller of estimated K or max feasible
  J_target <- min(K_hat, max_bins_possible)

  # Translate to bins_per_covariate
  n_bins_per_cov <- max(2, floor(J_target^(1/p)))

  return(n_bins_per_cov)
}
```

### Variance Calibration

**Type-level**: NO calibration
- Estimating correct target
- Variance is what it should be

**Covariate-level**: MODERATE calibration
- Empirically found to over-estimate variance by factor of 1.5-3x
- Use exponent calibration: alpha = 1 / inflation^k where k ~ 1.2-1.5
- k=1.3 achieves ~160% variance (conservative but reasonable)
- Alternative: k=1.5 achieves ~140% variance (less conservative)

**Observation-level**: NO calibration
- Already underestimates variance
- Calibration would make it worse

## Recommendations by Use Case

### Use Case 1: Types Known (Clinical Trial with Strata)

**Example**: Trial stratified by disease severity (mild, moderate, severe)

**Approach**: Type-level innovations
```r
result <- surrogate_inference_if(
  data = trial_data,
  type_variable = "severity",
  lambda = 0.3
)
```

**Expected performance**: Excellent (as validated)

### Use Case 2: Types Latent but Covariates Informative

**Example**: Surrogate validation with age, sex, biomarkers available

**Approach**: Covariate-level with adaptive binning
```r
result <- surrogate_inference_if(
  data = trial_data,
  covariates = c("age", "sex", "biomarker1", "biomarker2"),
  n_bins = "auto",  # Adaptive
  lambda = 0.3
)
```

**Expected performance**:
- K ≤ 20: Excellent correlation, conservative CIs
- K > 20: Degrades (document as limitation)

### Use Case 3: No Covariate Information

**Example**: Legacy trial data with only (A, S, Y)

**Approach**: Observation-level (with warning)
```r
result <- surrogate_inference_if(
  data = trial_data,
  lambda = 0.3
  # No type_variable or covariates
)
# Warning issued: "May underestimate variation"
```

**Expected performance**: Conservative (underestimates variation)

## Documentation

### User Guidance

**In package documentation**:

> The choice of innovation distribution affects what "future studies" means:
>
> - **type_variable**: Future studies differ in TYPE COMPOSITION. Use when types/strata are observed. Most accurate.
> - **covariates**: Future studies differ in COVARIATE DISTRIBUTION. Use when types are latent but covariates available. Works well when types ≤ 20.
> - **Neither**: Future studies are reweightings of observed individuals. Conservative (may underestimate variation).
>
> We recommend providing type_variable when available, otherwise covariates.

### Known Limitations

**Document clearly**:

1. **Large K (≥50) with weak correlation**: Fundamental challenge
   - Small sample per type (n/K ≤ 20) + weak signal (ρ < 0.7)
   - Bootstrap noise dominates
   - Consider parametric alternatives or accept wide CIs

2. **Covariate-level requires adequate covariates**:
   - Need enough covariates to capture heterogeneity
   - Rule of thumb: 2-3 covariates for K ≤ 20, 4-5 for K ≤ 100

3. **Variance calibration is conservative**:
   - Covariate-level produces CIs ~1.4-1.6x wider than nominal
   - Ensures coverage but reduces power
   - Accept as price of robustness

## Next Steps

1. **Implement hierarchical approach** in package/R/inference_influence_function.R
2. **Implement adaptive binning** (estimate K̂, choose J)
3. **Add type-level option** with mapping to observation weights
4. **Update documentation** with use case guidance
5. **Re-run validation** with type-level approach
6. **Write technical note** explaining theoretical foundations
7. **Update methods paper** (if needed) to clarify innovation distribution

## Open Questions

1. **Better K̂ estimation**: How to reliably estimate number of types from covariates?
   - Mixture models (BIC)
   - Hierarchical clustering (silhouette)
   - Information criteria

2. **Optimal calibration exponent**: Is k=1.3 always best or should it depend on J/n ratio?

3. **Parametric alternative**: For K ≥ 50, would GLM-based approach work better?

4. **Theory for growing k**: Can we prove convergence for k → ∞ at rate k = o(n)?

5. **Diagnostic for when method will fail**: Can we predict based on (K̂, n, ρ̂) when coverage will break down?
