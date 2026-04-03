# Data Generating Process (DGP) Scenarios for Validation

## Current Issue

The quick test showed **PPV = 1.000** in all cases, which means:
- Treatment effects are **always positive** (ΔS > 0 and ΔY > 0)
- This is too optimistic and doesn't test whether methods handle variation
- We need DGPs where the surrogate is sometimes **poor** (low correlation, low PPV)

---

## Proposed DGP Scenarios

### Good Surrogate (High Correlation, High PPV)

**Current DGP:**
```r
treatment_effect_surrogate = c(0.3, 0.9)  # Strong positive effect
treatment_effect_outcome = c(0.2, 0.8)    # Strong positive effect
```

**Expected:**
- Correlation: 0.6-0.8
- PPV (ε=0): 0.95-1.0
- **Use case:** Validates methods work when assumptions hold

---

### Moderate Surrogate (Medium Correlation, Medium PPV)

**Proposed DGP:**
```r
treatment_effect_surrogate = c(0.2, 0.7)  # Moderate effect
treatment_effect_outcome = c(0.1, 0.5)    # Weaker effect
```

**Expected:**
- Correlation: 0.4-0.6
- PPV (ε=0): 0.7-0.85
- **Use case:** Realistic scenario with heterogeneity

---

### Weak Surrogate (Low Correlation, Low PPV)

**Proposed DGP A: Weak Signal**
```r
treatment_effect_surrogate = c(0.05, 0.3)  # Weak surrogate effect
treatment_effect_outcome = c(0.05, 0.3)    # Weak outcome effect
```

**Expected:**
- Correlation: 0.3-0.5
- PPV (ε=0): 0.6-0.75
- **Use case:** Tests precision with weak signals

**Proposed DGP B: Uncorrelated**
```r
treatment_effect_surrogate = c(0.2, 0.7)   # Moderate surrogate
treatment_effect_outcome = c(-0.1, 0.4)    # Variable outcome (can be negative!)
```

**Expected:**
- Correlation: 0.1-0.3 (weak)
- PPV (ε=0): 0.5-0.7
- **Use case:** Surrogate is poor predictor

---

### Bad Surrogate (Near-Zero Correlation, PPV ≈ 0.5)

**Proposed DGP C: Opposite Effects**
```r
treatment_effect_surrogate = c(0.3, 0.8)   # Positive surrogate effect
treatment_effect_outcome = c(-0.3, 0.2)    # Outcome can be negative!
```

**Expected:**
- Correlation: -0.2 to 0.1 (near zero or negative)
- PPV (ε=0): 0.4-0.6 (surrogate is uninformative)
- **Use case:** Tests methods detect poor surrogates

---

### Heterogeneous Effects (High Variance)

**Proposed DGP D: Wide Range**
```r
treatment_effect_surrogate = c(-0.2, 1.0)  # Very heterogeneous
treatment_effect_outcome = c(-0.2, 0.9)    # Very heterogeneous
```

**Expected:**
- Correlation: 0.3-0.6 (moderate despite wide ranges)
- PPV (ε=0): 0.6-0.8
- **Use case:** Tests robustness to extreme heterogeneity

---

## Implementation Strategy

### Option 1: Multiple DGP Scenarios Per Script

**Modify each validation script to test multiple DGPs:**

```r
dgp_scenarios <- list(
  good = list(
    name = "Good Surrogate",
    te_surrogate = c(0.3, 0.9),
    te_outcome = c(0.2, 0.8)
  ),
  moderate = list(
    name = "Moderate Surrogate",
    te_surrogate = c(0.2, 0.7),
    te_outcome = c(0.1, 0.5)
  ),
  weak = list(
    name = "Weak Surrogate",
    te_surrogate = c(0.05, 0.3),
    te_outcome = c(0.05, 0.3)
  ),
  poor = list(
    name = "Poor Surrogate",
    te_surrogate = c(0.3, 0.8),
    te_outcome = c(-0.3, 0.2)
  )
)

# Outer loop over DGPs
for (dgp_name in names(dgp_scenarios)) {
  dgp <- dgp_scenarios[[dgp_name]]

  # Inner loops over lambda, thresholds, replications
  baseline <- generate_study_data(
    n = N_BASELINE,
    treatment_effect_surrogate = dgp$te_surrogate,
    treatment_effect_outcome = dgp$te_outcome,
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )

  # ... rest of validation
}
```

**Pros:**
- Comprehensive testing within each script
- Shows method performance across DGP quality

**Cons:**
- Much longer runtime (4x increase)
- More complex results to interpret

---

### Option 2: Separate DGP-Specific Scripts (Recommended)

**Create variant scripts for key validations:**

```
16a_probability_validation_good_surrogate.R      (current)
16b_probability_validation_weak_surrogate.R      (new)

18a_ppv_validation_good_surrogate.R              (current)
18b_ppv_validation_weak_surrogate.R              (new)
18c_ppv_validation_poor_surrogate.R              (new)

20a_tv_robustness_good_surrogate.R               (current)
20b_tv_robustness_weak_surrogate.R               (new)
```

**Pros:**
- Can run in parallel
- Cleaner results per DGP
- Easier to compare across DGP quality

**Cons:**
- More scripts to manage
- Some code duplication

---

### Option 3: Single DGP Parameter (Simplest)

**Add one "weak surrogate" scenario to test scripts:**

For scripts 16, 17, 18 (Type i validation):
- Keep current DGP (good surrogate)
- Add ONE weak surrogate scenario: `treatment_effect_outcome = c(-0.1, 0.4)`

For scripts 19, 20, 21 (Type ii-iv validation):
- Test BOTH good and weak surrogates
- Compare method performance

**Pros:**
- Minimal changes
- Tests key question: "Do methods work with poor surrogates?"

**Cons:**
- Less comprehensive than Option 1

---

## Recommendation

**For immediate testing:** Option 3 (simplest)

Add this to each script after defining the current DGP:

```r
# Test with both good and poor surrogate scenarios
dgp_scenarios <- list(
  good = list(
    name = "Good Surrogate",
    te_surrogate = c(0.3, 0.9),
    te_outcome = c(0.2, 0.8),
    expected_corr = 0.65,
    expected_ppv = 0.95
  ),
  poor = list(
    name = "Poor Surrogate",
    te_surrogate = c(0.3, 0.8),
    te_outcome = c(-0.3, 0.2),
    expected_corr = 0.05,
    expected_ppv = 0.55
  )
)
```

**Key question answered:**
- Do 95% CIs achieve nominal coverage **even when the surrogate is poor**?
- Do minimax bounds contain truth for **both good and bad surrogates**?

---

## Expected Results

### Type (i): Nominal Coverage
- **Good surrogate:** 95% coverage ✓
- **Poor surrogate:** Should still get 95% coverage ✓
  - Even if φ_true ≈ 0.05, the CI should contain it

### Type (ii): Minimax Bounds
- **Good surrogate:** Narrow bounds [0.60, 0.70]
- **Poor surrogate:** May have wider bounds [-0.1, 0.3] due to more uncertainty
  - But should still contain truth in 100% of cases

### Type (iii): TV-Robustness
- **Good surrogate:** Robust across mechanisms
- **Poor surrogate:** **CRITICAL TEST**
  - If bounds hold even with poor surrogate → strongest evidence of robustness
  - If bounds fail → suggests method requires minimum surrogate quality

### Type (iv): Cross-Prediction
- **Good surrogate:** Strong φ̂_corr → emp_PPV relationship
- **Poor surrogate:** Weak relationship expected
  - This is correct behavior (if surrogate is poor, estimates should reflect this)

---

## Implementation Steps

1. **Quick test with poor surrogate:**
   ```r
   # Modify test_script_18_quick.R
   baseline <- generate_study_data(
     n = N_BASELINE,
     treatment_effect_surrogate = c(0.3, 0.8),
     treatment_effect_outcome = c(-0.3, 0.2),  # POOR SURROGATE
     surrogate_type = "continuous",
     outcome_type = "continuous"
   )
   ```

2. **Run test:** See if we get PPV < 1.0 and whether CIs cover

3. **If successful:** Add DGP loop to scripts 18, 19, 20 (highest priority)

4. **For paper:** Report results separately for good vs. poor surrogate scenarios

---

## Paper Implications

### Current (All DGPs Good)
"When the surrogate has high correlation (ρ ≈ 0.65), methods achieve nominal coverage."

### After Adding Poor Surrogates
"Methods achieve nominal coverage **regardless of true surrogate quality**. For poor surrogates (ρ ≈ 0.05, PPV ≈ 0.55), 95% CIs still achieved 94% coverage, demonstrating that inference procedures correctly quantify uncertainty even when the surrogate provides minimal information."

**This is a STRONGER claim!**

---

## Conclusion

**Recommended approach:**
1. Test script 18 with poor surrogate DGP (5 min test)
2. If successful, add DGP parameter to scripts 18, 19, 20
3. Report results by DGP quality in paper

This strengthens all validation claims by showing methods work **even with bad surrogates**.
