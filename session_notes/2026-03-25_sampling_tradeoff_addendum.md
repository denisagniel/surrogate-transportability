# Addendum: Sampling vs Closed-Form Trade-off

**Date:** 2026-03-25
**Issue Raised:** User noted that sampling gives distributional information, not just minimum

---

## The Key Trade-off

### What We Sacrifice for Speed

**Closed-form concordance:**
- ✓ 9-500x faster
- ✓ Gives minimum (worst-case)
- ✓ Can compute maximum analytically (for linear functionals)
- ✗ **No mean, median, quantiles, variance**
- ✗ **No distributional shape information**
- ✗ **No risk profiling capabilities**

**Sampling (correlation or concordance):**
- ✗ 10-500x slower
- ✓ Full distribution over Q ∈ B_λ(P₀)
- ✓ All summaries: min, 5th/25th/75th/95th percentiles, median, mean, max, variance
- ✓ Risk profiling: conservative vs optimistic bounds
- ✓ Robustness assessment: narrow distribution = stable, wide = fragile

---

## When This Matters

### Scenario 1: Simple Threshold Decision (Closed-Form OK)
```r
# Question: "Is surrogate good enough in worst-case?"
phi_star <- concordance_closed_form(data, lambda)
decision <- if (phi_star > 0.5) "approve" else "reject"
```
**Distributional info not needed** → Closed-form perfect

### Scenario 2: Risk Management (Need Sampling)
```r
# Question: "What's our typical performance? How variable?"
phi_dist <- sample_concordance_distribution(data, lambda, M=2000)

risk_profile <- tibble(
  worst_5th = quantile(phi_dist, 0.05),  # Very conservative
  moderate = quantile(phi_dist, 0.25),   # Moderate
  typical = mean(phi_dist),               # Average case
  robust = sd(phi_dist) < 0.1             # Stability check
)
```
**Distributional info critical** → Sampling required

### Scenario 3: Multiple Studies/Portfolio (Need Sampling)
```r
# Question: "Which percentile should we use for different studies?"
phi_dist <- sample_distribution(data, lambda)

# High-risk study: use conservative bound
study_A_decision <- quantile(phi_dist, 0.05) > threshold

# Low-risk study: use typical performance
study_B_decision <- mean(phi_dist) > threshold

# Portfolio: use median
portfolio_decision <- median(phi_dist) > threshold
```
**Different risk attitudes** → Need full distribution

---

## Hybrid Solution (Recommended)

### API Design

```r
surrogate_inference_minimax(
  data,
  lambda = 0.3,
  functional_type = "concordance",
  compute_distribution = FALSE  # NEW parameter
)
```

**If `compute_distribution = FALSE` (default):**
- Use closed-form → 4ms
- Return only `phi_star` (minimum)

**If `compute_distribution = TRUE`:**
- Use sampling → 38ms
- Return:
  - `phi_star` (minimum)
  - `phi_mean` (typical)
  - `phi_median`
  - `phi_quantiles` (5th, 25th, 75th, 95th)
  - `phi_sd` (variability)
  - `phi_distribution` (full M samples)

### Example Workflow

```r
# 1. Fast screening
phi_min <- surrogate_inference_minimax(
  data, lambda = 0.3,
  functional_type = "concordance",
  compute_distribution = FALSE
)$phi_star

# 2. If close to boundary, get full distribution
if (abs(phi_min - threshold) < 0.1) {
  result_full <- surrogate_inference_minimax(
    data, lambda = 0.3,
    functional_type = "concordance",
    compute_distribution = TRUE
  )

  # Now have: mean, median, quantiles, variance
  cat("Typical performance:", result_full$phi_mean, "\n")
  cat("Variability:", result_full$phi_sd, "\n")
  cat("Conservative (5th):", result_full$phi_quantiles[1], "\n")
}
```

---

## Update to Comparison Documents

### Add to METHODS_COMPARISON_COMPREHENSIVE.md

**New section after performance comparison:**

> **Distributional Information vs Point Estimates**
>
> An important distinction: sampling-based approaches provide the full distribution of φ(Q) over the uncertainty set B_λ(P₀), while closed-form solutions provide only worst-case (minimum) or best-case (maximum) bounds.
>
> Sampling enables:
> - **Risk profiling:** 5th, 25th, 75th, 95th percentiles for different risk attitudes
> - **Uncertainty quantification:** Variance and spread of φ across the ball
> - **Robustness assessment:** Narrow distribution indicates stability; wide indicates sensitivity
> - **Portfolio management:** Different bounds for different contexts
>
> For decisions requiring only worst-case guarantees (e.g., regulatory approval with conservative threshold), closed-form concordance is ideal (4ms, minimum sufficient). For risk management requiring full uncertainty characterization, sampling provides richer information at 10-500× computational cost.
>
> A hybrid approach balances efficiency and depth: use closed-form for screening, then compute full distribution only at critical λ values or when near decision boundaries.

### Add to FINAL_METHODS_COMPARISON_RESULTS.md

**New row in summary table:**

| Aspect | Closed-Form | Sampling | Best For |
|--------|-------------|----------|----------|
| **Worst-case** | ✓ Instant | ✓ Slow | Both |
| **Mean/Median** | ✗ No | ✓ Yes | Sampling |
| **Quantiles** | ✗ No | ✓ Yes | Sampling |
| **Risk Profile** | ✗ No | ✓ Yes | Sampling |
| **Variance** | ✗ No | ✓ Yes | Sampling |
| **Comp. Time** | 4 ms | 38-1963 ms | Closed-form |

---

## Implementation Priority

**High (Next):**
- [ ] Add `compute_distribution` parameter to API
- [ ] Document trade-off in package vignette
- [ ] Update methods comparison docs (done above)

**Medium:**
- [ ] Implement hybrid function
- [ ] Examples showing when to use each

**Low:**
- [ ] Analytical bounds on mean/variance
- [ ] Approximate distribution methods

---

## Key Messages for Manuscript

### Discussion Section - Add Paragraph

> While closed-form solutions provide computational efficiency (4-5ms), they yield only worst-case bounds. Sampling-based approaches, though 10-500× slower, provide the full distribution of surrogate quality across the uncertainty set, enabling risk profiling and portfolio decision-making. For most regulatory decisions requiring conservative guarantees, worst-case bounds suffice. For risk management across multiple studies with varying risk tolerance, the full distribution adds value. A hybrid approach—screening with closed-form, then detailed sampling at critical values—balances efficiency and information content.

---

## Bottom Line

**You're absolutely right:**
- Sampling gives **rich distributional information**
- Closed-form gives **only min/max**
- This is a real trade-off, not just a pure win

**Recommendation:**
- **Default:** Closed-form (worst-case sufficient for most)
- **Upgrade:** Add flag for distribution when needed
- **Best:** Hybrid (screen → sample critical regions)

**Documentation updated:**
- `CLOSED_FORM_VS_SAMPLING_TRADEOFFS.md` (full analysis)
- `SAMPLING_VS_CLOSED_FORM_SUMMARY.txt` (visual guide)
- Session notes (this file)

**Next step:**
- Implement `compute_distribution` parameter in package API

---

**Status:** Trade-off documented and integrated into comparison
**Impact:** Clarifies when to use each approach
