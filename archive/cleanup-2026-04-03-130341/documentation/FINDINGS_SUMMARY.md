# Investigation Summary: Shrinkage + DRO for Selection Bias

**Date:** March 30, 2026

## Quick Summary

**Problem solved:** Shrinkage + DRO achieves 98% coverage (target 95%)
**Key question:** Is shrinkage factor 0.5 universally optimal?
**Answer (preliminary):** NO - optimal shrinkage varies by DGP characteristics

---

## What We've Confirmed

### 1. Shrinkage + DRO Works on Baseline DGP ✓

**Phase 2 Coverage Validation:**
- Coverage: 98% (target 95%)
- Bias: 0.0044 (essentially unbiased)
- RMSE: 0.0229 (excellent)
- 100/100 successful replications

**Comparison to naive:**
- Coverage: 39% → 98% (2.5× improvement)
- Bias: -0.064 → 0.004 (93% reduction)
- RMSE: 0.069 → 0.023 (67% reduction)

**Verdict:** Complete success on the DGP we tested in Phase 2

### 2. Cross-Fitting Helps But Isn't Essential ✓

**Test results (50 reps, shrinkage 0.5):**
- With cross-fit: RMSE = 0.024
- Without cross-fit: RMSE = 0.029
- Improvement: 18% (statistically significant, p=0.05)

**Verdict:** Use `cross_fit=TRUE` as conservative default

---

## What's Still Unknown

### 3. Does Shrinkage 0.5 Generalize? (IN PROGRESS)

**Robustness test:** Testing 8 DGP scenarios × 3 shrinkage factors (0.4, 0.5, 0.6)

**Early findings (first 15/54 conditions):**

| Scenario | Best Shrinkage | Notes |
|----------|----------------|-------|
| Baseline | 0.5 | As expected from Phase 2 |
| Strong hetero | 0.6 | More shrinkage better |
| Weak hetero | 0.4 | Less shrinkage better |
| **High noise** | **0.4** | **0.5 shows bias -0.052!** |
| Low noise | 0.6 | More shrinkage better |
| Correlated X | TBD | Testing now |
| Skewed X | TBD | Testing now |
| Nonlinear | TBD | Testing now |

**Pattern emerging:** Optimal shrinkage depends on:
- **Noise level:** High noise → less shrinkage (0.4)
- **Signal strength:** Strong effects → more shrinkage (0.6)
- **Heterogeneity:** Weak hetero → less shrinkage (0.4)

**Implication:** Fixed shrinkage 0.5 works "on average" but not optimally everywhere

---

## Tentative Conclusions (Pending Full Robustness Results)

### Option A: Fixed Shrinkage 0.5 (Simple)

**Pros:**
- Works well on baseline DGP
- Simple to implement and explain
- Achieves nominal coverage in our test case

**Cons:**
- Not universally optimal
- May perform poorly in high-noise scenarios
- Suboptimal in low-noise, strong-effect settings

**When to use:**
- Moderate noise and effect sizes
- When simplicity matters
- As reasonable default

### Option B: Adaptive Shrinkage Selection (Complex)

**Approach:** Choose shrinkage factor based on data characteristics
- Estimate noise level from residuals
- Estimate effect size from concordances
- Select shrinkage ∈ {0.4, 0.5, 0.6} based on rules

**Pros:**
- Optimal for each scenario
- Better coverage across DGPs
- Scientifically more satisfying

**Cons:**
- More complex
- Needs validation of selection rules
- Risk of overfitting to selection

**Rules (preliminary):**
```r
noise_level <- estimate_noise(data)
effect_strength <- estimate_effects(data)

if (noise_level > threshold_high) {
  shrinkage <- 0.4  # Less shrinkage for high noise
} else if (noise_level < threshold_low && effect_strength > threshold_strong) {
  shrinkage <- 0.6  # More shrinkage for low noise + strong effects
} else {
  shrinkage <- 0.5  # Default for moderate cases
}
```

### Option C: Ensemble Approach (Robust)

**Approach:** Average estimates from multiple shrinkage factors
- Compute φ̂₀.₄, φ̂₀.₅, φ̂₀.₆
- Take weighted or simple average
- Bootstrap from averaged estimates

**Pros:**
- Robust across scenarios
- Automatic adaptation
- May reduce variance

**Cons:**
- 3× computational cost
- Less interpretable
- May not be optimal anywhere

---

## What the Full Robustness Test Will Tell Us

**If shrinkage 0.5 works across >80% of scenarios:**
→ Use fixed shrinkage 0.5 with documentation of limitations

**If optimal shrinkage varies systematically:**
→ Develop adaptive selection rules (Option B)

**If no clear pattern:**
→ Use ensemble approach (Option C) or document "use 0.5 on average"

---

## Files

**Completed:**
- `phase2_systematic_debiasing.R` - Found shrinkage 0.5 best on baseline
- `phase2_coverage_validation.R` - Confirmed 98% coverage
- `test_cross_fitting_necessity.R` - Confirmed cross-fit helps 18%

**In Progress:**
- `phase2_robustness_testing.R` - Testing 8 DGPs (15/54 complete)

**Pending Full Results:**
- Decision on fixed vs adaptive shrinkage
- Package implementation
- Documentation

---

## Next Steps (After Robustness Complete)

1. **Analyze full robustness results**
   - Identify best shrinkage per scenario
   - Check if 0.5 is "good enough" everywhere
   - Develop adaptive rules if needed

2. **Make implementation decision**
   - Option A: Fixed 0.5 (simple)
   - Option B: Adaptive (complex, better)
   - Option C: Ensemble (robust, costly)

3. **Implement in package**
   - Add chosen method
   - Document limitations/guidance
   - Create vignette with examples

4. **Update manuscript**
   - Section 5: New method
   - Simulations: Updated results
   - Discussion: When to use, limitations

---

## Key Insight

**The selection bias problem has a solution** (shrinkage before DRO), but the **optimal shrinkage is context-dependent**, not universal.

This is both:
- **Good news:** We have a working method
- **Complication:** Need to decide between simplicity (fixed 0.5) vs optimality (adaptive)

**Scientific question:** Is "good enough on average" acceptable, or do we need "optimal everywhere"?
