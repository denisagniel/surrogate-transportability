# Solution: Innovation Distribution When Types Are Always Unobserved

**Date:** 2026-03-24
**Status:** Proposed solution

---

## The Core Problem

**Current situation:**
- Validation uses type-level innovations (K types) → high variation → correlation ≈ 0.7
- Package uses obs-level innovations (n observations) → low variation → correlation ≈ 0.2
- These test DIFFERENT estimands
- But we'll NEVER observe types in practice

**The fundamental question:** What is the RIGHT amount of compositional variation to model when types are latent?

---

## Option 1: Observation-Level IS Correct (Change the Validation)

### The Argument

**Maybe the package implementation is actually correct, and the validation is wrong.**

**Reasoning:**
- In practice, we observe n individuals from some population
- We want to know: "What happens in future samples from similar populations?"
- "Similar populations" = reweightings/resamplings of the observed population
- Observation-level innovations naturally capture this

**Estimand:** Surrogate quality for future samples that are reweightings of the observed population structure.

**Validation should be:**
```r
# Ground truth: ALSO use observation-level innovations
for (m in 1:M) {
  # Generate obs-level innovation (same as package)
  obs_weights_m <- rdirichlet(1, rep(1, n))[1,]

  # Form mixture at OBSERVATION level
  q_m_weights <- (1 - lambda) * p0_obs + lambda * obs_weights_m

  # Generate NEW sample with these weights
  new_sample <- generate_sample_with_obs_weights(population, q_m_weights)

  # Compute treatment effects
  ...
}
```

**This would match what the package does → validation would pass.**

**Advantages:**
- No need to know or estimate K
- Works with ANY population structure
- Package implementation unchanged
- Validation and package test same thing

**Disadvantages:**
- Doesn't capture the possibility of truly different population compositions
- Conservative (underestimates variability if populations really differ in composition)
- May not match users' intuition about "future studies"

---

## Option 2: Estimate Effective Dimensionality from Data

### The Insight

We don't need to know the TRUE types. We just need to estimate **how much heterogeneity exists** in the population.

### Approach: Empirical Heterogeneity Calibration

**Algorithm:**
1. Split data into G random groups (e.g., G=10)
2. Estimate treatment effects in each group
3. Compute variance of treatment effects across groups
4. Use this to calibrate the innovation distribution

**Intuition:**
- If treatment effects vary a lot across random splits → high heterogeneity → use low "effective K"
- If treatment effects are similar across splits → low heterogeneity → use high "effective K"

**Implementation:**
```r
# Estimate effective heterogeneity
estimate_effective_K <- function(data, G = 10, B = 100) {
  n <- nrow(data)

  # Bootstrap: compute between-group variance B times
  between_var_s <- numeric(B)
  between_var_y <- numeric(B)

  for (b in 1:B) {
    # Random split into G groups
    groups <- sample(rep(1:G, length.out = n))

    # Estimate treatment effects per group
    group_effects <- matrix(NA, G, 2)
    for (g in 1:G) {
      group_data <- data[groups == g, ]
      if (sum(group_data$A == 1) > 5 && sum(group_data$A == 0) > 5) {
        delta_s <- mean(group_data$S[group_data$A == 1]) -
                   mean(group_data$S[group_data$A == 0])
        delta_y <- mean(group_data$Y[group_data$A == 1]) -
                   mean(group_data$Y[group_data$A == 0])
        group_effects[g, ] <- c(delta_s, delta_y)
      }
    }

    # Variance across groups
    between_var_s[b] <- var(group_effects[, 1], na.rm = TRUE)
    between_var_y[b] <- var(group_effects[, 2], na.rm = TRUE)
  }

  # Mean between-group variance
  V_between <- mean(c(between_var_s, between_var_y))

  # Also compute within-group (sampling) variance
  V_within <- var(data$S) / (n/G)  # Approximate

  # Ratio tells us about heterogeneity
  # High ratio → more heterogeneity → smaller effective K
  ratio <- V_between / V_within

  # Map to effective K (heuristic)
  # ratio ≈ 0 → K_eff = n (no heterogeneity)
  # ratio >> 1 → K_eff small (high heterogeneity)
  K_eff <- round(n / (1 + 10 * ratio))
  K_eff <- max(4, min(K_eff, n))  # Bound between 4 and n

  list(K_effective = K_eff,
       variance_ratio = ratio,
       between_variance = mean(between_var_s))
}

# Use in inference
surrogate_inference_adaptive <- function(data, lambda, ...) {
  # Estimate effective K from data
  K_est <- estimate_effective_K(data)$K_effective

  message(sprintf("Estimated effective K: %d (from observed heterogeneity)", K_est))

  # Use this K for innovations
  # ... cluster into K_est groups or use K_est as Dirichlet concentration
}
```

**Advantages:**
- Data-driven (no arbitrary K choice)
- Adapts to actual heterogeneity
- Works without observing types

**Disadvantages:**
- Adds estimation step (more uncertainty)
- Heuristic mapping from variance to K
- May be unstable for small samples

---

## Option 3: Concentration Parameter Approach (RECOMMENDED)

### The Key Insight

**We don't need to choose K. We can parameterize the innovation distribution by its CONCENTRATION, not its dimension.**

### The Idea

Instead of:
```r
innovations <- rdirichlet(M, rep(alpha, K))  # Need to know K
```

Use:
```r
innovations <- rdirichlet(M, rep(alpha, n))  # Always use n
# But VARY alpha based on estimated heterogeneity
```

**Alpha controls how concentrated the distribution is:**
- `alpha = 1`: Uniform (standard Dirichlet)
- `alpha → 0`: Very concentrated (sparse, most weight on few observations)
- `alpha → ∞`: Very diffuse (nearly uniform)

**Small alpha ≈ Small K** (innovations create more variation)
**Large alpha ≈ Large K** (innovations create less variation)

### Implementation

```r
#' Estimate concentration parameter from observed heterogeneity
estimate_alpha_from_heterogeneity <- function(data, n_splits = 10, n_boot = 50) {
  n <- nrow(data)

  # Estimate between-group heterogeneity (as in Option 2)
  between_var <- estimate_between_variance(data, n_splits, n_boot)
  within_var <- estimate_within_variance(data)

  # Variance ratio
  het_ratio <- between_var / within_var

  # Map to alpha:
  # Low heterogeneity (ratio ≈ 0) → large alpha (≈ 1)
  # High heterogeneity (ratio >> 1) → small alpha (≈ 0.01)

  alpha_est <- 1 / (1 + 10 * het_ratio)
  alpha_est <- max(0.01, min(alpha_est, 1))  # Bound between 0.01 and 1

  alpha_est
}

surrogate_inference_if <- function(data, lambda,
                                   alpha = c("adaptive", "uniform"),
                                   ...) {
  n <- nrow(data)

  if (is.character(alpha) && alpha == "adaptive") {
    # Estimate alpha from data
    alpha_est <- estimate_alpha_from_heterogeneity(data)
    message(sprintf("Using adaptive alpha = %.3f (from observed heterogeneity)",
                    alpha_est))
  } else if (is.character(alpha) && alpha == "uniform") {
    alpha_est <- 1
  } else {
    alpha_est <- alpha
  }

  # Generate innovations with estimated alpha
  innovations <- MCMCpack::rdirichlet(n_innovations, rep(alpha_est, n))

  # Continue with bootstrap...
}
```

**Advantages:**
- ✅ Data-driven
- ✅ No need to estimate K
- ✅ Continuous tuning (not discrete K choices)
- ✅ Bayesian interpretation (alpha as prior)
- ✅ Easy to implement

**Disadvantages:**
- Still needs validation that the mapping (heterogeneity → alpha) is correct
- Adds estimation step

---

## Option 4: Match the Validation to the Estimand (SIMPLEST)

### The Realization

**The package is implementing a specific, well-defined estimand:**
- "Correlation of treatment effects across reweightings of the observed sample"
- This is observation-level innovation
- It's a valid estimand!

**The validation is testing a DIFFERENT estimand:**
- "Correlation across independent samples from populations with different type proportions"
- This is type-level innovation
- Also a valid estimand!

**Solution: Change the validation to match what the package does.**

### New Validation Approach

**Ground truth when types are unobserved:**

```r
# For each "innovation", generate sample using OBSERVATION-LEVEL weights
for (m in 1:M_true) {
  # Generate obs-level innovation (not type-level)
  obs_weights_m <- rdirichlet(1, rep(1, n_baseline))[1,]

  # Form Q_m at observation level
  p0 <- rep(1/n_baseline, n_baseline)
  q_m <- (1 - lambda) * p0 + lambda * obs_weights_m

  # The "ground truth" treatment effects come from:
  # Resampling the OBSERVED baseline with these weights
  # (Not generating new populations with different type distributions)

  boot_sample <- sample_with_replacement(baseline, probs = q_m)

  delta_s_m <- mean(boot_sample$S[boot_sample$A == 1]) -
               mean(boot_sample$S[boot_sample$A == 0])
  delta_y_m <- mean(boot_sample$Y[boot_sample$A == 1]) -
               mean(boot_sample$Y[boot_sample$A == 0])

  true_effects[m, ] <- c(delta_s_m, delta_y_m)
}

# Ground truth correlation: from obs-level innovations
true_corr <- cor(true_effects[, 1], true_effects[, 2])
```

**Then package method should match this ground truth.**

**Advantages:**
- ✅ No assumptions about types
- ✅ Works for any data
- ✅ Package unchanged
- ✅ Validation matches implementation

**Disadvantages:**
- Conservative (doesn't capture possibility of truly different populations)
- Users may expect broader external validity

---

## My Recommendation: Option 3 (Adaptive Alpha)

### Why This is Best

1. **Philosophically principled:**
   - Uses observed heterogeneity to calibrate
   - More heterogeneity → more concentrated innovations → more variation
   - Less heterogeneity → more diffuse innovations → less variation

2. **Practically feasible:**
   - No need to observe or estimate types
   - Continuous tuning (not discrete K)
   - Data-driven (not arbitrary)

3. **Validation works:**
   - Generate data with known heterogeneity
   - Check that estimated alpha recovers true variation
   - Verify coverage across heterogeneity levels

4. **User-friendly:**
   - Default: `alpha = "adaptive"` (automatic)
   - Option: `alpha = 1` (uniform, conservative)
   - Option: `alpha = 0.1` (user-specified if they have prior knowledge)

### Implementation Plan

**Step 1: Implement heterogeneity estimation**
- Function to estimate variance ratio
- Map to alpha parameter
- Add to package

**Step 2: Modify inference function**
```r
surrogate_inference_if(..., alpha = "adaptive", alpha_method = "variance_ratio")
```

**Step 3: Validate**
- Generate data with varying heterogeneity (K=4, 10, 50, 100)
- Check that adaptive alpha recovers appropriate variation
- Verify coverage

**Step 4: Compare to fixed approaches**
- alpha = "adaptive" vs alpha = 1 vs alpha = 0.1
- Show when adaptive helps vs doesn't matter

---

## Validation Strategy with Adaptive Alpha

```r
# Generate population with K_true types
population <- generate_population(K = 10, tau_s, tau_y)

# Generate ONE baseline sample
baseline <- sample_from_population(population, n = 1000)
# Note: baseline has latent types, but we don't observe them

# Ground truth: What is the correlation across population innovations?
# Use TYPE-LEVEL innovations (because we know true K in validation)
true_effects <- compute_with_type_innovations(population, K = 10, M = 500)
true_correlation <- cor(true_effects[, 1], true_effects[, 2])

# Method: Estimate from baseline WITHOUT knowing types
result <- surrogate_inference_if(
  baseline,  # No type column
  lambda = 0.3,
  alpha = "adaptive"  # Estimates heterogeneity from data
)

# Check coverage
covered <- (true_correlation >= result$ci_lower) &&
           (true_correlation <= result$ci_upper)
```

**Key:** Ground truth uses type-level (known K), but method estimates alpha from data.
If adaptive alpha works, it should recover the type-level variation without knowing types.

---

## Summary

**Four options when types are unobserved:**

1. **Obs-level is correct** → Change validation to match package (conservative)
2. **Estimate effective K** → Cluster data or use dimensionality reduction (complex)
3. **Adaptive alpha** ⭐ → Estimate concentration from heterogeneity (recommended)
4. **Match validation to estimand** → Obs-level for both (simplest)

**My recommendation: Option 3 (Adaptive Alpha)**
- Data-driven
- No need for types
- Continuous tuning
- Bayesian interpretation
- Should work across heterogeneity levels

**This solves the practical problem:** Method adapts to observed heterogeneity without needing to know or estimate types.
