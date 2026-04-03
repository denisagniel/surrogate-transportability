# Recommended DGP Scenarios for Validation Studies

**Date:** 2026-03-23
**Purpose:** Define DGP configurations that produce clear separation between good and bad surrogates

---

## Key Finding: Use Corrected No-Mediation DGP

**Critical:** All validation scripts must use `generate_study_data_no_mediation()` from `package/R/data_generators_corrected.R`.

**Why:** The original `generate_study_data()` has a hard-coded S→Y path (Y depends on 0.7*S), which prevents independent control of treatment effects on S and Y. This makes it impossible to test scenarios where the surrogate is uninformative or misleading.

**What the corrected DGP does:**
- Removes the S→Y causal path
- S and Y are correlated only through shared dependence on treatment, covariates, and latent class
- Allows independent specification of treatment effects on S and Y
- Tests **surrogate predictiveness** (cross-study TE correlation) rather than mediation

---

## Recommended Scenario Set

Based on empirical testing (test_better_dgp.R, test_uncorrelated_surrogate.R), use these three scenarios:

### Scenario 1: GOOD SURROGATE (High Correlation, High PPV)

**Configuration:**
```r
te_surrogate = c(0.3, 0.9)   # Low class → high class
te_outcome   = c(0.2, 0.8)   # Also low → high (parallel pattern)
lambda = 0.3
n_classes = 2
```

**Expected Performance:**
- Cross-study correlation: **0.40-0.50**
- PPV: **1.00** (all positive effects)
- Interpretation: Surrogate reliably predicts outcome effects

---

### Scenario 2: WEAK SURROGATE (Moderate Correlation, Low PPV)

**Configuration:**
```r
te_surrogate = c(0.2, 0.8)   # Positive (low → high)
te_outcome   = c(-0.5, 0.5)  # Crosses zero! (negative → positive)
lambda = 0.3
n_classes = 2
```

**Expected Performance:**
- Cross-study correlation: **0.35-0.40** (moderate, still positive)
- PPV: **0.20-0.30** (low - surrogate often wrong about sign)
- Interpretation: Surrogate sometimes predicts, sometimes misleads

**Why this works:** When populations shift toward Class 1 vs. Class 2, TE_Y can be negative or positive, but TE_S is always positive. This produces low PPV even though correlation is moderate.

---

### Scenario 3: BAD SURROGATE (Low Correlation, Zero PPV)

**Configuration:**
```r
te_surrogate = c(0.3, 0.9)   # Positive (low → high)
te_outcome   = c(-0.8, -0.2) # Both negative! (anti-correlated)
lambda = 0.3
n_classes = 2
```

**Expected Performance:**
- Cross-study correlation: **0.15-0.20** (very low, near zero)
- PPV: **0.00** (surrogate always wrong - predicts positive, outcome is negative)
- Interpretation: Surrogate is worse than useless (misleading)

**Why this works:** TE_S is always positive, TE_Y is always negative. When populations shift, both vary in magnitude but never in sign. Result: zero PPV, very low correlation.

---

### Alternative: OPPOSITE-PATTERN SURROGATE (Negative Correlation, High PPV)

**Configuration:**
```r
te_surrogate = c(0.2, 1.0)   # Low → high
te_outcome   = c(0.9, 0.1)   # HIGH → low (opposite!)
lambda = 0.5                 # CRITICAL: need larger λ for variation
n_classes = 2
```

**Expected Performance:**
- Cross-study correlation: **-0.03 to 0.10** (near zero or slightly negative)
- PPV: **1.00** (all effects still positive)
- Interpretation: Surrogate magnitude anti-correlates with outcome magnitude

**Trade-off:** Larger λ means assuming more perturbation between current and future studies. Use this only if λ=0.5 is scientifically justified.

---

## Scenario Comparison Table

| Scenario | TE_S Pattern | TE_Y Pattern | λ | Correlation | PPV | Use Case |
|----------|--------------|--------------|---|-------------|-----|----------|
| **GOOD** | Low→High (0.3, 0.9) | Low→High (0.2, 0.8) | 0.3 | 0.40-0.50 | 1.00 | Baseline (methods should work) |
| **WEAK** | Low→High (0.2, 0.8) | Neg→Pos (-0.5, 0.5) | 0.3 | 0.35-0.40 | 0.20-0.30 | Test low PPV handling |
| **BAD** | Low→High (0.3, 0.9) | Neg→Neg (-0.8, -0.2) | 0.3 | 0.15-0.20 | 0.00 | Test misleading surrogate |
| **OPPOSITE** (alt) | Low→High (0.2, 1.0) | High→Low (0.9, 0.1) | 0.5 | -0.03 to 0.10 | 1.00 | Test negative correlation |

---

## Implementation Checklist for Validation Scripts

When updating validation scripts (16-21):

1. **Source corrected DGP:**
   ```r
   source("package/R/data_generators_corrected.R")
   ```

2. **Use no-mediation function:**
   ```r
   baseline <- generate_study_data_no_mediation(
     n = N_BASELINE,
     treatment_effect_surrogate = <vector>,
     treatment_effect_outcome = <vector>,
     surrogate_type = "continuous",
     outcome_type = "continuous"
   )
   ```

3. **Test all three scenarios:**
   - Good (control - methods should work)
   - Weak (low PPV test)
   - Bad (zero PPV, near-zero correlation test)

4. **Report both correlation AND PPV:**
   - Correlation measures linear relationship of treatment effects
   - PPV measures sign agreement (practical utility)
   - A good surrogate needs both high

---

## Why These Scenarios Work

### Good Surrogate
- Both TE_S and TE_Y increase with class → positive correlation
- Both always positive → PPV = 1.0
- Clear best-case baseline

### Weak Surrogate
- TE_S always positive, TE_Y changes sign → moderate correlation
- Sign mismatch in ~75% of studies → low PPV (~0.25)
- Tests whether methods can detect unreliability

### Bad Surrogate
- TE_S positive, TE_Y negative → near-zero correlation
- Complete sign mismatch → PPV = 0.0
- Tests worst-case: misleading surrogate

### Key Insight
With only 2 classes and λ=0.3, we can't get strongly negative correlations (would need more classes or larger λ). But we CAN get:
- Near-zero correlations (0.15-0.20)
- Zero or low PPV (0.0-0.3)

This is sufficient to test whether methods correctly identify poor surrogates.

---

## Design Principles Learned

1. **Mediation vs. Predictiveness:** Original DGP tested mediation (does Y depend on S?). Corrected DGP tests predictiveness (does TE_S predict TE_Y across populations?).

2. **Cross-study correlation matters:** Within-study correlation of S and Y is NOT the right metric. We need correlation of *treatment effects* across multiple perturbed populations.

3. **PPV is crucial:** High correlation but low PPV means the surrogate predicts magnitude but not direction. This is useless for decision-making.

4. **Two classes are sufficient:** With good parameter choices, 2 classes provide enough variation. More classes or larger λ help but aren't strictly necessary.

5. **Negative TE values are key:** To get low PPV, we need scenarios where TE_Y can be negative while TE_S remains positive (or vice versa).

---

## Next Steps

1. Update scripts 16-21 to use corrected DGP
2. Add GOOD, WEAK, and BAD scenarios to each script
3. Report both correlation and PPV in results tables
4. Verify that methods:
   - Achieve 95% coverage for all scenarios (Type i)
   - Minimax bounds contain truth for all scenarios (Type ii)
   - Correctly estimate low PPV for WEAK/BAD scenarios
   - Don't break down when surrogate is poor

---

## References

- `package/R/data_generators_corrected.R` - Corrected DGP implementation
- `test_better_dgp.R` - Empirical tests of design options
- `test_uncorrelated_surrogate.R` - Tests of GOOD/WEAK/BAD scenarios
- Session notes 2026-03-23 - Design rationale and empirical results
