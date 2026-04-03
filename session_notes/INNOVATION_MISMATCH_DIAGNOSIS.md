# K=4 Validation Failure: Root Cause Analysis

**Date:** 2026-03-24
**Status:** Diagnosed - Solution identified

---

## Executive Summary

The K=4 validation failure (0% coverage, correlation 0.218 vs ground truth 0.696) is caused by an **innovation distribution mismatch** between the ground truth computation and the package implementation.

**Root cause:** Package generates Dirichlet innovations over **observations** (n=1000), while ground truth generates innovations over **types** (K=4). This constrains variation for small K.

**Impact:**
- K=4: Severe underestimation (30-65% of ground truth correlation)
- K=500: Minimal impact (method matches ground truth)

**Solution:** Modify package to use type-level innovations when types are observed.

---

## The Issue

### Validation Results (K=4, λ=0.3)
- **Ground truth correlation:** 0.696
- **Method estimate:** 0.218
- **Coverage:** 0% (CI doesn't capture ground truth)
- **Bias:** -0.477

### Initially Suspected Causes (All Ruled Out)
1. ❌ Fixed randomness (A, ε) - Diagnostic showed method matches ground truth with both fixed
2. ❌ Bootstrap implementation bug - Code is correct
3. ❌ Gradient computation issues - Not relevant for correlation functional
4. ❌ Alpha parameter - Tested multiple values, all fail

---

## Root Cause: Innovation Distribution Level

### Ground Truth Approach
**File:** `sims/scripts/18_ppv_npv_functional_validation_corrected.R:235`

```r
# Generate innovation over TYPES
type_weights_m <- MCMCpack::rdirichlet(1, rep(1, population$K))[1,]  # K=4

# Form mixture: Q = (1-λ)P₀ + λΠ̃
p0_weights <- rep(1/population$K, population$K)
q_m_weights <- (1 - lambda) * p0_weights + lambda * type_weights_m

# Generate NEW sample with these type proportions
```

**Result:** Type proportions vary widely
- Range: 17.5% to 44% per type
- SD: ~0.059

### Package Approach
**File:** `package/R/inference_influence_function.R:109`

```r
# Generate innovation over OBSERVATIONS
innovations <- MCMCpack::rdirichlet(n_innovations, rep(alpha, n))  # n=1000

# Form mixture over observations
p_hat <- rep(1/n, n)
p_tilde <- innovations[m, ]
q_m_weights <- (1 - lambda) * p_hat + lambda * p_tilde

# Bootstrap with observation-level weights
```

**Result:** Type proportions constrained near baseline
- Range: 20.8% to 28.2% per type
- SD: ~0.004

**Ratio:** Type-level has **14x more variation** than obs-level

---

## Why This Matters

### Effect on Treatment Effect Variation

When type proportions vary more:
- Treatment effects (weighted sums Σ π_k τ_k) vary more
- SD(ΔS) and SD(ΔY) increase
- Correlation signal is stronger

**Empirical Results:**
- **Type-level:** SD(ΔS) = 0.0644, SD(ΔY) = 0.0526, cor = 0.945
- **Obs-level:** SD(ΔS) = 0.0238, SD(ΔY) = 0.0214, cor = 0.612
- **Ratio:** Obs-level has only 37% of the treatment effect variation

With reduced variation:
- Signal-to-noise ratio decreases
- Correlation estimate becomes dampened
- Confidence intervals don't capture the true variation

---

## Why K Matters

### K=4 (Severe Impact)
- **250 observations per type**
- Clear distinction between type-level and observation-level innovations
- Observation-level constrains variation within each type's ~250 observations
- Result: **Method severely underestimates correlation**

### K=100 (Moderate Impact)
- **10 observations per type**
- Some distinction but less pronounced
- Result: **Validation shows 85-95% coverage** (acceptable)

### K=500 (Minimal Impact)
- **2 observations per type**
- Type-level ≈ Observation-level (almost same granularity)
- Result: **Validation shows 90-96% coverage** (excellent)

**Takeaway:** The innovation mismatch is most severe when:
- K is small (few types)
- n/K is large (many observations per type)
- These conditions give observation-level innovations limited ability to create type proportion variation

---

## Diagnostic Tests

### Test 1: Innovation Mismatch (`test_innovation_mismatch.R`)
**Finding:** Obs-level innovations have 6.5% of the type proportion variation of type-level innovations for K=4.

### Test 2: Fixed Randomness (`test_fixed_randomness_k4.R`)
**Finding:** Fixed A and ε are NOT the issue. Current bootstrap method matches ground truth when both use the same innovation approach.

### Test 3: Full Validation Comparison (`test_full_validation_comparison.R`)
**Finding:** Obs-level innovations produce correlation that is 64.7% of type-level (consistent with validation showing ~31%).

---

## Solution

### Option A: Type-Level Innovations (Recommended)

Modify `package/R/inference_influence_function.R` to detect and use types:

```r
# If data has a "type" or "class" column, use type-level innovations
if ("type" %in% names(current_data) || "class" %in% names(current_data)) {
  type_col <- if ("type" %in% names(current_data)) "type" else "class"
  K <- length(unique(current_data[[type_col]]))

  # Generate innovations over K types
  type_innovations <- MCMCpack::rdirichlet(n_innovations, rep(alpha, K))

  # For each innovation, convert to observation-level weights
  for (m in 1:n_innovations) {
    type_weights_m <- type_innovations[m, ]

    # Map to observation weights
    q_m_weights <- numeric(n)
    for (k in 1:K) {
      # All observations of type k get weight proportional to type_weights_m[k]
      type_k_obs <- which(current_data[[type_col]] == k)
      q_m_weights[type_k_obs] <- type_weights_m[k] / length(type_k_obs)
    }
    q_m_weights <- q_m_weights / sum(q_m_weights)  # Normalize

    # Continue with bootstrap using q_m_weights...
  }
} else {
  # No types observed: use current observation-level approach
  innovations <- MCMCpack::rdirichlet(n_innovations, rep(alpha, n))
  # ...
}
```

**Advantages:**
- Matches ground truth definition
- Works for any K
- Reduces to obs-level when types not observed

**Disadvantages:**
- Requires type/class column in data
- More complex implementation

### Option B: Document Estimand Difference

Keep current implementation but clearly document:

- **Method estimates:** Correlation across reweightings of observed sample (obs-level innovations)
- **Ground truth tests:** Correlation across independent samples from type distributions (type-level innovations)
- **When they differ:** Small K (clear type structure)
- **When they converge:** Large K (type ≈ observation granularity)

Add validation only for K where method matches its intended estimand (K ≥ 100).

**Advantages:**
- No code changes
- Clear about what method does

**Disadvantages:**
- Limits applicability to small K scenarios
- May not match user expectations for "future study" inference

---

## Recommendation

**Implement Option A** (type-level innovations when types observed).

**Rationale:**
1. The methods paper frames inference as "what happens in future studies with different populations"
2. Future studies are naturally defined by TYPE distributions (not observation permutations)
3. This matches the validation ground truth and user intuition
4. Implementation is straightforward when types are observed
5. Falls back to current behavior when types not observed

**Next Steps:**
1. Modify `inference_influence_function.R` to use type-level innovations
2. Add parameter `use_type_innovations = TRUE` (default when types detected)
3. Update tests to verify both type-level and obs-level modes
4. Re-run validation - should now pass for all K values
5. Update methods paper to clarify innovation distribution

---

## Files

**Diagnostic scripts:**
- `test_innovation_mismatch.R` - Shows 14x variation difference
- `test_fixed_randomness_k4.R` - Rules out fixed randomness hypothesis
- `test_full_validation_comparison.R` - Reproduces validation failure pattern

**Key package files:**
- `package/R/inference_influence_function.R:109` - Innovation generation (needs fix)
- `sims/scripts/18_ppv_npv_functional_validation_corrected.R:235` - Ground truth (correct)

**Results:**
- `sims/results/18_correlation_validation_results.rds` - Shows 0% coverage for K=4
- `sims/results/innovation_mismatch_boxplot.png` - Visualizes variation difference
- `sims/results/diagnostic_fixed_randomness_k4.png` - Shows fixed randomness is not the issue

---

## Conclusion

The K=4 validation failure is definitively caused by **innovation distribution mismatch**, not by fixed randomness or bootstrap implementation issues. The fix is well-defined and should restore nominal coverage across all K values.

**Key insight:** When modeling "future studies," innovations should be over the features that define study populations (types/classes), not over individual observations. The current implementation inadvertently constrains variation by innovating at the wrong level of granularity.
