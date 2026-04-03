# Validation Framework Status

**Last Updated:** 2026-03-23
**Status:** Major correction in progress

---

## Current Status: CRITICAL ISSUES IDENTIFIED & PARTIALLY RESOLVED

### ✓ Completed

1. **Identified fundamental problem** with reweighting approach
   - Reweighting underestimates variation by 20x
   - Produces correlations ~0.3 instead of ~0.98
   - Cannot distinguish good from bad surrogates

2. **Implemented corrected DGP**
   - `generate_study_data_no_mediation()` removes S→Y path
   - Allows independent control of TE_S and TE_Y
   - Tests surrogate predictiveness (not mediation)

3. **Verified independent sampling approach**
   - Produces intuitive results
   - SD(TE) ~0.18 (vs 0.008 for reweighting)
   - Clear separation between good and bad surrogates

4. **Identified correlation insufficiency**
   - With 2-class DGPs, all correlations ~±0.98
   - Need 4-class DGPs for meaningful variation
   - Need both PPV and NPV, not just correlation

5. **Implemented NPV functional**
   - Added `functional_npv()` to package
   - Integrated into `surrogate_inference_if()`
   - Integrated into `surrogate_inference_minimax()`
   - Package documentation rebuilt

6. **Created comprehensive documentation**
   - `CRITICAL_METHODOLOGICAL_CORRECTION.md` - full analysis
   - `RECOMMENDED_DGP_SCENARIOS.md` - DGP guidance
   - `VALIDATION_FRAMEWORK_SUMMARY.md` - original framework doc
   - `sims/DGP_SCENARIOS.md` - DGP design options

7. **Created diagnostic tests**
   - `diagnose_correlation_issue.R` - proves reweighting problem
   - `test_independent_samples_approach.R` - validates independent sampling
   - `test_ppv_npv_validation.R` - demonstrates PPV/NPV need
   - `test_npv_functional.R` - verifies NPV implementation
   - `test_better_dgp.R` - tests DGP design options
   - `test_corrected_dgp.R` - validates no-mediation DGP

---

## ✗ Not Yet Done

### Validation Scripts (6 scripts need updating)

**Current state:** All use reweighting approach with 2-class DGPs

**Required changes:**
1. Source `package/R/data_generators_corrected.R`
2. Switch from `generate_study_data()` to `generate_study_data_no_mediation()`
3. Use 4-class DGPs instead of 2-class
4. Replace reweighting with independent sampling for ground truth
5. Test multiple scenarios (EXCELLENT, HIGH_PPV_LOW_NPV, LOW_PPV_HIGH_NPV, BAD)
6. For PPV-related scripts: add NPV testing

**Scripts:**

1. ⚠ **`sims/scripts/16_probability_functional_validation.R`**
   - Type (i): Nominal coverage under correct model
   - Functional: Probability P(ΔY > ε_Y | ΔS > ε_S)
   - Status: Variable capture fix applied, needs full update

2. ⚠ **`sims/scripts/17_conditional_mean_validation.R`**
   - Type (i): Nominal coverage under correct model
   - Functional: E[ΔY | ΔS = δ]
   - Status: Variable capture fix applied, needs full update

3. ⚠ **`sims/scripts/18_ppv_functional_validation_corrected.R`**
   - Type (i): Nominal coverage under correct model
   - Functional: PPV P(ΔY > ε | ΔS > ε)
   - Status: Variable capture fix applied, needs full update
   - **Priority: HIGH** (should add NPV here too)

4. ⚠ **`sims/scripts/19_minimax_all_functionals.R`**
   - Type (ii): Minimax bounds over μ class
   - All four functionals: correlation, probability, conditional_mean, PPV
   - Status: Variable capture fix applied, needs full update
   - **Priority: HIGH** (should add NPV)

5. ⚠ **`sims/scripts/20_tv_robustness_validation.R`**
   - Type (iii): Model-free TV distance guarantees
   - Tests 5 Q-generation mechanisms
   - Status: Variable capture fix applied, needs full update
   - **Priority: CRITICAL** (strongest claim in paper)

6. ⚠ **`sims/scripts/21_cross_functional_prediction.R`**
   - Type (iv): Cross-functional prediction
   - Tests whether φ̂_A predicts empirical φ_B
   - Status: Variable capture fix applied, needs full update
   - Should include NPV in correlation matrix

---

## Recommended DGP Scenarios (4-Class)

Use these for all validation scripts:

### EXCELLENT (baseline - methods should work)
```r
te_s = c(-0.6, -0.2, 0.2, 0.6)
te_y = c(-0.5, -0.1, 0.1, 0.5)
# Expected: Corr ~0.98, PPV ~0.93, NPV ~0.92
```

### HIGH_PPV_LOW_NPV (test PPV alone insufficient)
```r
te_s = c(-0.5, -0.1, 0.3, 0.7)
te_y = c(0.1, 0.2, 0.3, 0.7)  # Y always positive!
# Expected: Corr ~0.91, PPV ~1.00, NPV ~0.00
```

### LOW_PPV_HIGH_NPV (test NPV alone insufficient)
```r
te_s = c(-0.7, -0.3, 0.1, 0.5)
te_y = c(-0.7, -0.5, -0.3, -0.1)  # Y always negative!
# Expected: Corr ~0.97, PPV ~0.00, NPV ~1.00
```

### BAD (worst case - opposite signs)
```r
te_s = c(-0.6, -0.2, 0.2, 0.6)
te_y = c(0.5, 0.1, -0.1, -0.5)  # Opposite!
# Expected: Corr ~-0.97, PPV ~0.10, NPV ~0.11
```

### RANDOM (optional - no pattern)
```r
te_s = c(-0.5, 0.1, 0.3, 0.6)
te_y = c(0.2, -0.4, 0.5, -0.1)
# Expected: Corr ~-0.08, PPV ~0.59, NPV ~0.23
```

---

## Expected Outcomes After Correction

### Type (i): Nominal Coverage

- All scenarios should achieve ~95% coverage
- EXCELLENT: High point estimates for correlation, PPV, NPV
- HIGH_PPV_LOW_NPV: PPV ~1.0, NPV ~0.0
- LOW_PPV_HIGH_NPV: PPV ~0.0, NPV ~1.0
- BAD: Low/negative correlation, low PPV, low NPV

### Type (ii): Minimax Bounds

- Bounds should contain truth for all scenarios
- Expected coverage: ~98-100% (by construction)
- Bound width should vary by functional

### Type (iii): TV-Robustness

- **Critical test:** Bounds should hold for mechanisms not in our model
- Expected coverage: ≥95% for mixture, covariate_shift, selection
- May have violations for extreme/adversarial mechanisms

### Type (iv): Cross-Functional Prediction

- Strong diagonal: φ̂_A predicts emp_A (r > 0.8)
- Moderate off-diagonal: some functionals predict others
- Include NPV in correlation matrix

---

## Priority Order for Updates

1. **Script 18 (PPV validation)** - Proof of concept, add NPV
2. **Script 20 (TV-robustness)** - Most critical for paper claims
3. **Script 19 (Minimax all functionals)** - Add NPV, test bounds
4. **Scripts 16-17** (Probability, Conditional mean) - Complete Type (i)
5. **Script 21** (Cross-functional) - Add NPV to matrix

---

## Success Criteria

✓ All scripts use independent sampling (not reweighting)
✓ All scripts use 4-class DGPs
✓ Results show intuitive patterns (see Expected Outcomes)
✓ Coverage rates near 95% for all scenarios
✓ Minimax bounds contain truth
✓ TV-robustness demonstrated
✓ PPV and NPV both tested where relevant

---

## Time Estimate

- **Per script update:** 1-2 hours
- **6 scripts total:** 9-12 hours
- **Full validation re-run:** 4-6 hours compute
- **Documentation/verification:** 2-3 hours

**Total:** ~15-20 hours

---

## Next Steps

1. Pick one script (recommend 18 - PPV) as proof of concept
2. Apply all corrections to that script
3. Run and verify results are intuitive
4. Use as template for remaining scripts
5. Run full validation suite
6. Update methods paper if needed

---

## Files Modified Today

### Package Files
- `package/R/surrogate_functionals.R` - Added `functional_npv()`
- `package/R/inference_influence_function.R` - Added NPV support
- `package/R/inference_minimax.R` - Added NPV support
- `package/man/*.Rd` - Rebuilt documentation

### Test Files (Created)
- `diagnose_correlation_issue.R` - Proves reweighting problem
- `test_independent_samples_approach.R` - Validates independent sampling
- `test_ppv_npv_validation.R` - Demonstrates PPV/NPV need
- `test_npv_functional.R` - Verifies NPV implementation
- `test_better_dgp.R` - Tests DGP designs
- `test_corrected_dgp.R` - Tests no-mediation DGP
- `test_uncorrelated_surrogate.R` - Tests weak/bad surrogates

### Documentation Files (Created)
- `CRITICAL_METHODOLOGICAL_CORRECTION.md` - Full analysis
- `VALIDATION_STATUS.md` - This file
- `sims/RECOMMENDED_DGP_SCENARIOS.md` - DGP guidance

---

## Questions for User

1. Should we proceed with updating script 18 as proof of concept?
2. Any other scenarios we should test beyond the 4-5 listed?
3. Should validation scripts be run in parallel (SLURM) or sequentially?
4. Do we need to update the methods paper text based on these corrections?
