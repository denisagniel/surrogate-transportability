# Practical Guidance: Innovation Distribution When Types Are Unobserved

**Date:** 2026-03-24
**Status:** Analysis and recommendations

---

## The Fundamental Problem

We've identified that **type-level innovations** are needed for proper inference about transportability across populations. But in practice, **types are usually unobserved**.

This creates a dilemma:
- **Validation studies:** We generate data with known types → can use type-level innovations
- **Real applications:** Types are latent/unobserved → cannot directly use type-level innovations

---

## What the Innovation Level Means

### Observation-level innovations (current implementation)
```r
innovations <- rdirichlet(M, rep(alpha, n))
```

**Estimand:** "What happens in future samples from populations with **similar composition** to the observed sample?"

**Captures:** Sampling variability (within fixed population composition)

**Does NOT capture:** Compositional variability (across populations with different type proportions)

**Appropriate when:**
- Future studies sample from same underlying population
- Composition is fixed or changes little
- Focus is on sampling uncertainty, not external validity

### Type-level innovations (proposed fix for validation)
```r
innovations <- rdirichlet(M, rep(alpha, K))
```

**Estimand:** "What happens in future studies from populations with **varying composition**?"

**Captures:** Both sampling variability AND compositional variability

**Requires:** Knowing K and observing/inferring types

**Appropriate when:**
- Future studies have different population compositions
- Transportability across populations is the goal
- Types are observed OR can be reliably estimated

---

## The Single-Sample Limitation

**Fundamental fact:** A single sample cannot distinguish between:
1. Sampling variability (drawing different individuals from same population)
2. Compositional variability (populations with different type proportions)

Without additional assumptions or data, we cannot learn about compositional variation from one sample.

This is analogous to the **external validity problem** in causal inference:
- **Internal validity:** Does treatment work in THIS population? (sampling)
- **External validity:** Does it work in OTHER populations? (composition)

Most single-study methods focus on internal validity. External validity requires:
- Multiple studies from different populations, OR
- Strong parametric assumptions about population structure

---

## Practical Solutions

### Solution 1: When Types Are Observed (Best Case)

**Scenarios:**
- Hospitals, clinics, sites in a multi-site study
- Demographic groups (age × sex × race categories)
- Geographic regions
- Disease subtypes
- Any observed grouping that might define "populations"

**Implementation:**
```r
# Detect types in data
if ("type" %in% names(data) || "site" %in% names(data) || "cluster" %in% names(data)) {
  # Use type-level innovations
  K <- length(unique(data$type))
  type_innovations <- rdirichlet(M, rep(alpha, K))

  # Convert to observation weights
  obs_weights <- map_type_to_obs_weights(type_innovations, data$type)
}
```

**Interpretation:** CIs capture both sampling and compositional variability (across observed types).

**Limitation:** Only captures variability over OBSERVED types, not unobserved heterogeneity.

---

### Solution 2: Estimate Types from Data (Middle Ground)

**When to use:**
- Types are latent but you suspect small K
- Strong prior belief about population structure
- Willing to make modeling assumptions

**Approaches:**

#### A. Clustering
```r
# K-means, hierarchical clustering, or mixture models
library(mclust)
fit <- Mclust(data[, c("S", "Y", covariates)])
K_estimated <- fit$G
types_estimated <- fit$classification
```

**Pros:**
- Data-driven
- Can use cross-validation to select K

**Cons:**
- Model uncertainty (is K correct?)
- Clustering might not reflect relevant heterogeneity
- Adds another layer of estimation

#### B. Latent Class Analysis
```r
# Estimate finite mixture model
library(flexmix)
fit <- flexmix(Y ~ A * S + covariates, data = data, k = K)
types_estimated <- clusters(fit)
```

**Pros:**
- Probabilistically principled
- Can incorporate covariates
- Provides uncertainty about classification

**Cons:**
- Requires specifying K
- Strong parametric assumptions
- May be unstable for small samples

#### C. Effective Dimensionality
```r
# Use PCA or entropy-based measures
pca <- prcomp(data[, c("S", "Y", covariates)])
K_eff <- sum(cumsum(pca$sdev^2) / sum(pca$sdev^2) < 0.95)
```

**Pros:**
- Quick approximation
- No hard clustering needed

**Cons:**
- Indirect measure
- May not reflect relevant structure

**Recommendation for this approach:**
1. Estimate K using multiple methods (clustering, mixture models, PCA)
2. If estimates agree, use that K
3. If estimates disagree, perform sensitivity analysis (see Solution 3)
4. Document uncertainty about K in interpretation

---

### Solution 3: Sensitivity Analysis (Most Conservative)

**When to use:**
- Uncertain about population structure
- Want to bound the uncertainty
- Providing evidence for policy/decision-making

**Implementation:**
```r
# Run analysis under different K assumptions
K_values <- c(4, 10, 25, 50, 100, n)
results <- list()

for (K in K_values) {
  # Cluster data into K groups (or use uniform assumption)
  if (K < n) {
    types_assumed <- kmeans(data[, c("S", "Y")], centers = K)$cluster
  } else {
    types_assumed <- 1:n  # Each observation is own type
  }

  # Run inference with these types
  results[[K]] <- surrogate_inference_if(
    data_with_types(data, types_assumed),
    lambda = lambda,
    use_type_innovations = TRUE
  )
}

# Report range
cat("Correlation estimates under different K assumptions:\n")
for (K in K_values) {
  cat(sprintf("  K=%4d: %.3f [%.3f, %.3f]\n",
              K, results[[K]]$estimate,
              results[[K]]$ci_lower, results[[K]]$ci_upper))
}
```

**Interpretation:**
- If results are similar across K → robust, less concern
- If results vary substantially with K → need to think carefully about K
- Conservative: use small K (wider CIs, more conservative)
- Liberal: use large K (narrower CIs, assumes less heterogeneity)

**Recommendation:** Report results under K=10, K=50, K=100 as a range.

---

### Solution 4: Accept Limitation, Document Clearly (Most Honest)

**When to use:**
- No strong prior about K
- Don't want to make arbitrary modeling choices
- Being transparent about what can/cannot be learned

**Implementation:**
```r
# Use current observation-level approach
results <- surrogate_inference_if(data, lambda = lambda,
                                 use_bootstrap = TRUE)
```

**Documentation:**
```
"Our method estimates surrogate quality for future samples from populations
with similar composition to the observed sample. Confidence intervals capture
sampling variability but not compositional variability (differences in
population structure across future studies).

Interpretation: If future populations have similar distributions of
patient types as our sample, we expect [result with CI]. If future
populations have substantially different compositions, additional
uncertainty should be considered.

This is a standard limitation of single-sample inference about
transportability. Assessing compositional variability would require
either (a) multiple samples from different populations, or
(b) strong parametric assumptions about population structure."
```

**When this is acceptable:**
- Exploratory analysis
- Hypothesis generation
- Preliminary evidence
- Clearly documented as conditional inference

---

## Decision Framework

### Step 1: Are types observed in your data?

**YES** → Use **Solution 1** (type-level innovations with observed types)
- Best case scenario
- No additional assumptions needed
- Captures relevant compositional variation

**NO** → Continue to Step 2

### Step 2: Do you have strong prior beliefs about K?

**YES** (e.g., "I think there are ~5-10 distinct subgroups) → Use **Solution 2** or **Solution 3**
- Solution 2: Estimate types, use those
- Solution 3: Sensitivity analysis across plausible K values

**NO** → Continue to Step 3

### Step 3: How much heterogeneity do you expect?

**HIGH heterogeneity, small K** (K ~ 5-20):
- Use **Solution 3** (sensitivity analysis)
- Report conservative estimates (small K)
- Acknowledge limitation explicitly

**MODERATE heterogeneity** (K ~ 50-100):
- Either **Solution 3** (sensitivity) or **Solution 4** (document limitation)
- Results may not be too sensitive to K in this range

**LOW heterogeneity, K ≈ n** (each person is own "type"):
- Use **Solution 4** (current approach)
- Observation-level ≈ type-level when K is large
- No meaningful distinction to make

### Step 4: What is your goal?

**Decision-making / policy**: Use **Solution 3** (sensitivity analysis)
- Show range of plausible results
- Conservative: use small K for wider CIs
- Let decision-makers see how sensitive conclusions are to assumptions

**Scientific inference**: Use **Solution 2** or **Solution 4**
- Solution 2 if willing to model types
- Solution 4 if prefer assumption-free approach
- Document limitations clearly

**Methods development**: Use **Solution 1** in validation
- Generate data with known types
- Validate that method works correctly when assumptions met
- In applications, revert to Solution 2-4 as appropriate

---

## Recommendation for This Project

### For Validation Studies
**Use Solution 1 with known types:**
- Generate data with K types (K=4, 10, 50, 100, 500)
- Use type-level innovations (correct approach for known types)
- This validates that the METHOD works correctly
- Achieves nominal coverage when innovation level matches ground truth

### For Package Implementation
**Provide flexibility:**

```r
surrogate_inference_if <- function(data,
                                   lambda,
                                   use_type_innovations = c("auto", "yes", "no"),
                                   type_column = NULL,
                                   assumed_K = NULL,
                                   ...) {

  use_type_innovations <- match.arg(use_type_innovations)

  if (use_type_innovations == "auto") {
    # Auto-detect types
    if (!is.null(type_column) && type_column %in% names(data)) {
      use_type_innovations <- "yes"
    } else {
      use_type_innovations <- "no"
      warning("No types detected. Using observation-level innovations. ",
              "Results are conditional on similar population composition. ",
              "See ?surrogate_inference_if for options.")
    }
  }

  if (use_type_innovations == "yes") {
    # Type-level innovations
    if (!is.null(type_column)) {
      types <- data[[type_column]]
      K <- length(unique(types))
    } else if (!is.null(assumed_K)) {
      # Cluster into assumed_K types
      types <- cluster_data(data, K = assumed_K)
      K <- assumed_K
    } else {
      stop("type_column or assumed_K required for type-level innovations")
    }

    # Generate type-level innovations
    innovations <- rdirichlet(M, rep(alpha, K))
    obs_weights <- map_types_to_obs(innovations, types)

  } else {
    # Observation-level innovations (current approach)
    innovations <- rdirichlet(M, rep(alpha, nrow(data)))
    obs_weights <- innovations
  }

  # Continue with bootstrap...
}
```

**Usage examples:**
```r
# If types observed (e.g., hospitals)
results <- surrogate_inference_if(data, lambda = 0.3, type_column = "hospital")

# If types unobserved but K assumed
results <- surrogate_inference_if(data, lambda = 0.3, assumed_K = 10)

# Default: observation-level (with warning)
results <- surrogate_inference_if(data, lambda = 0.3)
# Warning: Using observation-level innovations...

# Sensitivity analysis
for (K in c(10, 50, 100)) {
  results[[K]] <- surrogate_inference_if(data, lambda = 0.3, assumed_K = K)
}
```

### For Methods Paper

**Be clear about assumptions and limitations:**

1. **Estimand section:**
   - "Our method estimates surrogate quality for future samples from populations with varying composition"
   - "When population composition (type proportions) varies, we use type-level innovations"
   - "When types are unobserved, users can: (a) specify types if observed, (b) estimate K and cluster, (c) conduct sensitivity analysis, or (d) use observation-level innovations with documented limitation"

2. **Validation section:**
   - "We validate with known types to show the method works correctly when assumptions are met"
   - "In practice, types may be observed (e.g., study sites) or unobserved (latent heterogeneity)"

3. **Discussion:**
   - "As with all single-sample transportability methods, we cannot learn about compositional variability without observing types or making parametric assumptions"
   - "Our approach provides valid inference conditional on population composition. Users should consider whether future populations are likely to differ substantially in composition."

---

## Summary

**Key insight:** The innovation distribution level determines what variability we capture.

**In validation (types known):** Use type-level innovations → method works correctly

**In practice (types unknown):**
1. **Best:** Use observed types (sites, clusters, strata)
2. **Good:** Estimate K, conduct sensitivity analysis
3. **Acceptable:** Use obs-level, document limitation clearly

**Fundamental limitation:** Single sample cannot learn about compositional variability without additional assumptions. This is not a flaw in our method—it's a limitation of single-sample inference about transportability that affects all similar methods.

**Recommendation:** Implement flexible package that supports both approaches, with clear documentation about when each is appropriate. Let users choose based on their domain knowledge and inferential goals.
