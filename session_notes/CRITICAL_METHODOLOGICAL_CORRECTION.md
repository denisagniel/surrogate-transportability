# CRITICAL METHODOLOGICAL CORRECTION

**Date:** 2026-03-23
**Status:** URGENT - Affects all validation studies
**Impact:** Reweighting approach fundamentally flawed; entire validation framework needs revision

---

## Executive Summary

We discovered **two critical problems** with our validation approach:

1. **Reweighting severely underestimates variation** (SD ~ 0.008 vs 0.18 for independent samples - 20x difference)
2. **Correlation alone is insufficient** for surrogate evaluation (need both PPV and NPV)

These issues mean:
- Current validation results are **invalid**
- Reweighting approach **does not match** what happens with independent studies
- Need to switch to **independent sampling** for ground truth
- Need to evaluate **both PPV and NPV** functionals

---

## Problem 1: Reweighting Underestimates Variation

### What We Found

**Test:** Generated good surrogate DGP with TE_S = (0.3, 0.9), TE_Y = (0.2, 0.8)

**Reweighting approach** (current method):
- Cross-study correlation: **0.345**
- SD(TE_S): **0.008**
- SD(TE_Y): **0.009**

**Independent samples approach** (correct):
- Cross-study correlation: **0.983**
- SD(TE_S): **0.178**
- SD(TE_Y): **0.179**

### Why This Happens

**Reweighting:**
```r
q_weights <- (1 - lambda) * p0 + lambda * p_tilde
delta_s <- sum(q_weights * data$S * data$A) / sum(q_weights * data$A) - ...
```

- Just rearranges weights on the **same 2000 observations**
- Those observations have **fixed noise realizations**
- Variation we see is mostly **resampling noise**, not true population variation
- For lambda=0.3, the q_weights are 70% uniform, 30% random → very limited actual variation

**Independent sampling:**
```r
new_study <- generate_study_data_no_mediation(
  n = 2000, class_probs = class_probs_m, ...
)
delta_s <- mean(new_study$S[A==1]) - mean(new_study$S[A==0])
```

- Generates **truly new observations** with new noise
- Captures **actual population-level variation** when class mixture changes
- SD 20x larger (~0.18 vs 0.008)

### Impact

The reweighting correlation (0.345) is closer to the **within-study correlation** (0.47) than to the **true cross-study correlation** (0.983). This means:
- We're picking up artifacts and noise
- Not capturing true cross-study patterns
- **Good surrogates look mediocre** (correlation 0.35 instead of 0.98)
- **Bad surrogates also look mediocre** (correlation 0.30 instead of near-zero)
- Impossible to distinguish good from bad surrogates

---

## Problem 2: Correlation Alone is Misleading

### What We Found

With 2-class DGPs and Dirichlet(1,1) innovation, we're sampling along a **line segment**:
- Class 1: (TE_S₁, TE_Y₁)
- Class 2: (TE_S₂, TE_Y₂)

**All correlations are ±0.98** regardless of surrogate quality!

| Scenario | TE_S | TE_Y | Correlation | PPV | NPV |
|----------|------|------|-------------|-----|-----|
| GOOD | (0.3, 0.9) | (0.2, 0.8) | **0.982** | 1.000 | (not applicable - all positive) |
| WEAK | (0.2, 0.8) | (-0.5, 0.5) | **0.988** | 0.528 | (mixed) |
| BAD | (0.3, 0.9) | (-0.8, -0.2) | **0.985** | 0.000 | (not applicable - Y all negative) |
| OPPOSITE | (0.2, 1.0) | (0.9, 0.1) | **-0.984** | 1.000 | (not applicable - all positive) |

**Correlation determined by slope, not surrogate quality!**

### Solution: Use 4-Class DGPs + PPV/NPV

With 4 classes spanning negative to positive effects:

| Scenario | TE_S | TE_Y | Corr | PPV | NPV | Quality |
|----------|------|------|------|-----|-----|---------|
| **EXCELLENT** | (-0.6, -0.2, 0.2, 0.6) | (-0.5, -0.1, 0.1, 0.5) | 0.977 | 0.926 | 0.922 | ✓✓ |
| **HIGH_PPV_LOW_NPV** | (-0.5, -0.1, 0.3, 0.7) | (0.1, 0.2, 0.3, 0.7) | 0.908 | **1.000** | **0.000** | ✗ |
| **LOW_PPV_HIGH_NPV** | (-0.7, -0.3, 0.1, 0.5) | (-0.7, -0.5, -0.3, -0.1) | 0.966 | **0.000** | **1.000** | ✗ |
| **BAD** | (-0.6, -0.2, 0.2, 0.6) | (0.5, 0.1, -0.1, -0.5) | -0.969 | 0.099 | 0.105 | ✗✗ |
| **RANDOM** | (-0.5, 0.1, 0.3, 0.6) | (0.2, -0.4, 0.5, -0.1) | -0.075 | 0.593 | 0.231 | ✗ |

**Key Insight:** A good surrogate needs **BOTH** high PPV and high NPV. High PPV alone (1.0) with low NPV (0.0) means the surrogate predicts positive effects well but completely fails on negative effects.

---

## What We've Implemented

### 1. Corrected DGP (No Mediation)

**File:** `package/R/data_generators_corrected.R`

**Function:** `generate_study_data_no_mediation()`

**What it does:**
- Removes S→Y causal path
- S and Y correlated only through shared treatment/class/covariate effects
- Allows independent control of TE_S and TE_Y
- Tests **surrogate predictiveness**, not mediation

**Original DGP problem:**
```r
Y[class_idx] <- treatment_effect_outcome[v] * A[class_idx] +
                0.7 * S[class_idx] +  # ← HARD-CODED S→Y path!
                ...
```
This made `treatment_effect_outcome` parameter not control total TE on Y.

**Corrected DGP:**
```r
S[class_idx] <- treatment_effect_surrogate[v] * A[class_idx] + ...
Y[class_idx] <- treatment_effect_outcome[v] * A[class_idx] + ...  # NO S TERM
```

### 2. NPV Functional

**File:** `package/R/surrogate_functionals.R`

**Function:** `functional_npv(treatment_effects, epsilon_s, epsilon_y)`

**What it computes:** NPV = P(ΔY ≤ ε_Y | ΔS ≤ ε_S)

**Why we need it:** Complements PPV to assess surrogate quality for both positive and negative predictions.

**Now supported in:**
- `functional_npv()` - standalone functional
- `surrogate_inference_if()` - influence function method
- `surrogate_inference_minimax()` - minimax bounds
- `compute_functional_with_ci()` - bootstrap CIs

---

## Required Changes to Validation Framework

### 1. Switch to Independent Samples for Ground Truth

**Current (WRONG):**
```r
# Generate innovations and reweight SAME baseline
innovations <- MCMCpack::rdirichlet(N_TRUE_STUDIES, rep(1, n))
for (m in 1:N_TRUE_STUDIES) {
  q_weights <- (1 - lambda) * p0 + lambda * innovations[m, ]
  delta_s <- compute_treatment_effect_weighted(baseline, "S", q_weights)
  delta_y <- compute_treatment_effect_weighted(baseline, "Y", q_weights)
  true_effects[m, ] <- c(delta_s, delta_y)
}
```

**Corrected (RIGHT):**
```r
# Generate INDEPENDENT studies with different class mixtures
for (m in 1:N_TRUE_STUDIES) {
  class_probs_m <- MCMCpack::rdirichlet(1, rep(1, n_classes))[1,]

  new_study <- generate_study_data_no_mediation(
    n = 2000,
    n_classes = 4,  # Use 4 classes!
    class_probs = class_probs_m,
    treatment_effect_surrogate = te_s,
    treatment_effect_outcome = te_y,
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )

  delta_s <- mean(new_study$S[new_study$A == 1]) - mean(new_study$S[new_study$A == 0])
  delta_y <- mean(new_study$Y[new_study$A == 1]) - mean(new_study$Y[new_study$A == 0])
  true_effects[m, ] <- c(delta_s, delta_y)
}
```

### 2. Use 4-Class DGPs Instead of 2-Class

**Why:** More variation in patterns, effects cross zero, meaningful correlation differences.

**Recommended scenarios:**

```r
# EXCELLENT: High PPV + high NPV
te_s = c(-0.6, -0.2, 0.2, 0.6)
te_y = c(-0.5, -0.1, 0.1, 0.5)

# HIGH_PPV_LOW_NPV: Test PPV alone insufficient
te_s = c(-0.5, -0.1, 0.3, 0.7)
te_y = c(0.1, 0.2, 0.3, 0.7)  # Y always positive!

# LOW_PPV_HIGH_NPV: Test NPV alone insufficient
te_s = c(-0.7, -0.3, 0.1, 0.5)
te_y = c(-0.7, -0.5, -0.3, -0.1)  # Y always negative!

# BAD: Opposite signs
te_s = c(-0.6, -0.2, 0.2, 0.6)
te_y = c(0.5, 0.1, -0.1, -0.5)  # Opposite pattern!

# RANDOM: No pattern
te_s = c(-0.5, 0.1, 0.3, 0.6)
te_y = c(0.2, -0.4, 0.5, -0.1)
```

### 3. Test Both PPV and NPV

**Update all validation scripts to:**
1. Compute both PPV and NPV for ground truth
2. Estimate both using `surrogate_inference_if()`
3. Check coverage for **both** functionals
4. Report results for both in tables

---

## Impact on Existing Work

### Scripts Affected (ALL validation scripts)

1. **`sims/scripts/16_probability_functional_validation.R`** - Type (i) validation
2. **`sims/scripts/17_conditional_mean_validation.R`** - Type (i) validation
3. **`sims/scripts/18_ppv_functional_validation_corrected.R`** - Type (i) validation
4. **`sims/scripts/19_minimax_all_functionals.R`** - Type (ii) validation
5. **`sims/scripts/20_tv_robustness_validation.R`** - Type (iii) validation
6. **`sims/scripts/21_cross_functional_prediction.R`** - Type (iv) validation

### Changes Required

**For each script:**

1. **Source corrected DGP:**
   ```r
   source("package/R/data_generators_corrected.R")
   ```

2. **Switch to 4-class independent sampling:**
   ```r
   # OLD: 2-class reweighting
   baseline <- generate_study_data(n = 1000, ...)

   # NEW: 4-class no-mediation
   baseline <- generate_study_data_no_mediation(
     n = 1000, n_classes = 4, ...
   )
   ```

3. **Use independent samples for ground truth:**
   ```r
   # Replace reweighting loop with independent sampling loop
   # (see example above)
   ```

4. **Test multiple scenarios:**
   - EXCELLENT (baseline - methods should work)
   - HIGH_PPV_LOW_NPV (test PPV alone insufficient)
   - LOW_PPV_HIGH_NPV (test NPV alone insufficient)
   - BAD (test worst case)

5. **Add NPV testing** (for PPV-related scripts):
   ```r
   result_npv <- surrogate_inference_if(
     baseline, lambda = lambda,
     functional_type = "npv",
     epsilon_s = epsilon_s, epsilon_y = epsilon_y
   )
   ```

---

## Verification Checklist

Before considering validation complete, verify:

- [ ] All scripts use `generate_study_data_no_mediation()` from corrected DGP
- [ ] All scripts use independent sampling (not reweighting) for ground truth
- [ ] All scripts use 4-class DGPs
- [ ] All scripts test multiple scenarios (EXCELLENT, HIGH_PPV_LOW_NPV, LOW_PPV_HIGH_NPV, BAD)
- [ ] Scripts 18, 19, 20, 21 test **both PPV and NPV**
- [ ] Results show intuitive patterns:
  - EXCELLENT: High correlation, high PPV, high NPV
  - HIGH_PPV_LOW_NPV: High PPV (~1.0), low NPV (~0.0)
  - LOW_PPV_HIGH_NPV: Low PPV (~0.0), high NPV (~1.0)
  - BAD: Low/negative correlation, low PPV, low NPV
- [ ] Coverage rates near 95% for all scenarios (Type i)
- [ ] Minimax bounds contain truth for all scenarios (Type ii)

---

## Timeline Estimate

**Per script update:** ~1-2 hours (6 scripts × 1.5 hours = **9 hours**)
**Full re-run of validation:** ~4-6 hours compute time
**Documentation/review:** ~2 hours

**Total:** ~15-17 hours to complete corrected validation framework

---

## Next Steps

1. **Immediate:** Document this correction in session notes
2. **Today:** Update one script (script 18 - PPV) as proof of concept
3. **This week:** Update remaining 5 scripts
4. **After re-run:** Update methods paper if validation results change

---

## Key Lessons Learned

1. **Always compare to independent samples** when validating reweighting approaches
2. **Check SD of estimates** - if it's tiny, you're not capturing real variation
3. **Correlation can be misleading** - need domain-specific metrics (PPV/NPV)
4. **Test with DGPs spanning zero** - essential for meaningful variation
5. **User intuition was correct** - "these numbers don't make sense" → fundamental issue

---

## References

- `diagnose_correlation_issue.R` - Empirical evidence of reweighting problem
- `test_independent_samples_approach.R` - Comparison of methods
- `test_ppv_npv_validation.R` - PPV/NPV with 4-class DGPs
- `test_npv_functional.R` - NPV functional verification
- `package/R/data_generators_corrected.R` - Corrected DGP implementation
- `package/R/surrogate_functionals.R` - NPV functional added (lines 234-298)
