# Adaptive vs Fixed Shrinkage: Decision Framework

**Date:** March 30, 2026
**Status:** Testing in progress

---

## The Journey So Far

### Phase 1: Baseline Success (Shrinkage 0.5)
- Tested on single DGP (linear, moderate noise)
- **Coverage: 98%** ✓
- Bias: 0.0044, RMSE: 0.024
- Concluded: Problem solved!

### Phase 2: User Question - "How general is this?"
- Tested across 8 DGP scenarios
- **Result: Shrinkage 0.5 fails in ~40% of conditions**
- Catastrophic failures:
  - Strong heterogeneity: bias +0.128
  - High noise: bias -0.067
- Fixed 0.6 wins 41% of conditions vs 20% for 0.5

### Phase 3: User Decision - "Adaptive selection" (Current)
Testing adaptive rules that select 0.4, 0.5, or 0.6 based on data characteristics

---

## Three Options Evaluated

### Option A: Fixed Shrinkage 0.6
**Performance from robustness test:**
- Overall RMSE: 0.062 (best among fixed)
- Wins 41% of conditions
- Still fails in high noise scenarios

**Pros:**
- Simple (one parameter)
- Better than 0.5 overall
- Reduces strong heterogeneity bias

**Cons:**
- Not optimal in high noise
- Still suboptimal in 59% of conditions

### Option B: Adaptive Selection (Chosen)
**Approach:** Select shrinkage based on estimated noise and effect strength

**Rules:**
```r
noise_level <- estimate_noise_sd(data)
effect_strength <- median(abs(concordances))

if (noise_level > 0.55) → shrinkage = 0.4
else if (effect_strength > 0.15) → shrinkage = 0.6
else if (effect_strength < 0.08) → shrinkage = 0.4
else → shrinkage = 0.5
```

**Hypothesis:** Adaptive beats both fixed 0.5 and 0.6

**Testing:** 5 scenarios × 50 reps (in progress)

**Pros (if successful):**
- Optimal for each scenario
- Addresses specific failure modes
- Scientifically principled

**Cons:**
- More complex
- Additional estimation step
- Risk of misselection

### Option C: Fixed 0.5 with Warnings (Rejected)
- Simple but known failures
- Only 20% of conditions optimal
- Not recommended

---

## Adaptive Selection Implementation Details

### Noise Estimation
```r
estimate_noise_level <- function(data, outcome, covariates) {
  # Fit linear model to get residuals
  fit <- lm(outcome ~ A + X1 + X2, data = data)

  # Robust MAD estimator
  sd_robust <- mad(residuals(fit), constant = 1.4826)

  return(sd_robust)
}
```

**Why MAD?** Robust to outliers, doesn't require normality

### Effect Strength Estimation
```r
estimate_effect_strength <- function(concordances) {
  # Median absolute concordance
  median(abs(concordances))
}
```

**Why median?** Robust to extreme values, stable estimate

### Decision Thresholds (Calibrated from Robustness Test)

| Characteristic | Low | Moderate | High |
|---------------|-----|----------|------|
| Noise SD | < 0.35 | 0.35-0.55 | > 0.55 |
| Effect strength | < 0.08 | 0.08-0.15 | > 0.15 |

**Shrinkage mapping:**
- High noise → 0.4 (from robustness: high noise best with 0.4)
- Strong effects → 0.6 (from robustness: strong hetero best with 0.6)
- Weak effects → 0.4 (from robustness: weak hetero best with 0.4)
- Moderate → 0.5 (baseline)

---

## What We're Testing Now

**5 challenging scenarios:**
1. **Baseline** - Should select 0.5 (moderate)
2. **Strong heterogeneity** - Should select 0.6 (strong effects)
3. **High noise** - Should select 0.4 (high noise)
4. **Low noise** - Should select 0.6 (low noise + effects)
5. **Weak heterogeneity** - Should select 0.4 (weak effects)

**Comparison:**
- Adaptive (rule-based selection)
- Fixed 0.5 (original Phase 2 default)
- Fixed 0.6 (robustness test winner)

**Metrics:**
- Overall RMSE (primary)
- RMSE by scenario
- Statistical significance (paired t-tests)
- Selection frequency by scenario

---

## Decision Criteria

### If Adaptive Wins
✓ Adaptive RMSE < Fixed 0.6 RMSE **AND** statistically significant (p < 0.05)

**→ Implement adaptive as default**
- Provide `shrink_factor = "adaptive"` (default)
- Allow `shrink_factor = 0.4/0.5/0.6` (user override)
- Document: "Adaptive selection based on data characteristics"

### If Fixed 0.6 Wins
✓ Fixed 0.6 RMSE ≤ Adaptive RMSE

**→ Use fixed 0.6 as default**
- Simpler is better if performance equal
- Provide `shrink_factor = 0.6` (default)
- Document: "Based on extensive robustness testing"

### If Mixed Results
No clear winner (adaptive better in some, fixed better in others)

**→ Offer both options**
- Default: Fixed 0.6 (simpler)
- Advanced: Adaptive (for optimal performance)
- Document trade-offs clearly

---

## Expected Test Results (Predictions)

**Scenario-specific expectations:**

| Scenario | Adaptive Should Select | Expected Winner |
|----------|----------------------|-----------------|
| Baseline | 0.5 | Adaptive ≈ Fixed 0.5 |
| Strong hetero | 0.6 | Adaptive ≈ Fixed 0.6 |
| High noise | 0.4 | **Adaptive >> Both fixed** |
| Low noise | 0.6 | Adaptive ≈ Fixed 0.6 |
| Weak hetero | 0.4 | **Adaptive >> Both fixed** |

**Overall prediction:** Adaptive wins due to strong advantage in high noise and weak hetero scenarios

**RMSE improvement estimate:** 15-25% over fixed 0.5

---

## Implementation Plan (If Adaptive Wins)

### 1. Package Function
```r
shrinkage_minimax_wasserstein <- function(
  data,
  covariates,
  lambda_w,
  shrink_factor = "adaptive",  # Default: adaptive
  tau_method = "kernel",
  cross_fit = TRUE,
  n_bootstrap = 500
) {

  if (shrink_factor == "adaptive") {
    # Adaptive selection
    selection <- select_shrinkage_adaptive(data, covariates)
    shrink <- selection$shrinkage
    message("Adaptive: Selected shrinkage = ", shrink,
            " (", selection$reason, ")")
  } else {
    # User-specified fixed value
    shrink <- as.numeric(shrink_factor)
  }

  # Apply shrinkage + DRO
  result <- compute_shrinkage_dro(data, covariates, lambda_w, shrink)

  # Bootstrap CI
  ci <- bootstrap_ci(data, covariates, lambda_w, shrink, n_bootstrap)

  list(
    phi_star = result$phi_star,
    ci_lower = ci$ci_lower,
    ci_upper = ci$ci_upper,
    shrinkage_used = shrink,
    selection_reason = if (shrink_factor == "adaptive") selection$reason else "User-specified"
  )
}
```

### 2. Documentation
- Vignette: "Adaptive Shrinkage Selection for DRO"
- Explain: when adaptive helps, when to override
- Examples: high noise, strong effects, typical cases

### 3. Testing
- Unit tests for selection logic
- Integration tests for full pipeline
- Coverage validation with adaptive method

### 4. Manuscript Updates
- Section 5.3: "Adaptive Shrinkage Correction"
- Explain selection rules and rationale
- Show robustness test results
- Compare to fixed approaches

---

## Risk Mitigation

### Risk 1: Misselection
**Problem:** Adaptive selects wrong shrinkage factor

**Mitigation:**
- Conservative thresholds (better to be moderate than extreme)
- Allow user override
- Provide diagnostic output (show noise/effect estimates)

### Risk 2: Overfitting to Robustness Test
**Problem:** Rules work on test scenarios but not general data

**Mitigation:**
- Use simple, interpretable rules
- Based on fundamental properties (noise, effect strength)
- Validate on held-out scenarios
- Document when to use fixed instead

### Risk 3: Computational Cost
**Problem:** Extra estimation step slows things down

**Assessment:** Marginal (~5% overhead for noise estimation)
**Mitigation:** Fast estimation methods (linear model residuals)

---

## Fallback Plan

### If Adaptive Fails in Testing
**Fallback:** Use Fixed 0.6 as default

**Justification:**
- Fixed 0.6 proven better than 0.5 overall
- Simpler to implement and explain
- Known failure modes (high noise only)

**Documentation:**
- "Default shrinkage factor: 0.6 (based on robustness testing)"
- "For very noisy data, consider shrinkage = 0.4"
- Show robustness test results in vignette

---

## Timeline

**Current:** Adaptive validation running (~10-15 min)

**After results:**
- If adaptive wins: Implement + coverage validation (2-3 hours)
- If fixed wins: Update defaults + document (1 hour)

**Tomorrow:**
- Package implementation
- Unit tests
- Documentation
- Manuscript updates

**Deliverable:** Working method with nominal coverage, validated across DGPs

---

## Success Criteria

**Minimum acceptable:**
- Coverage ≥ 93% on baseline DGP
- RMSE < 0.04 on average across scenarios
- No catastrophic failures (|bias| > 0.10)

**Ideal:**
- Coverage 94-96% on baseline
- RMSE < 0.035 overall
- Consistent performance across DGPs

**Current status:**
- Baseline coverage: 98% ✓ (with fixed 0.5)
- Need to verify with adaptive selection

---

## Key Questions to Answer

1. **Does adaptive beat fixed 0.6?** (Primary question)
2. **By how much?** (Practical significance)
3. **Is selection reliable?** (Picks right shrinkage consistently?)
4. **Is complexity justified?** (Worth the extra code?)

**Results pending...**
