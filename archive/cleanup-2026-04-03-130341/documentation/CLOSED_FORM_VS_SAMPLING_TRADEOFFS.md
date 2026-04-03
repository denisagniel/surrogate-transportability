# Closed-Form vs Sampling: Trade-offs and Hybrid Approaches

**Key Insight:** Sampling provides **distributional information**; closed-form provides only **point estimates** (min/max).

---

## What Sampling Gives Us (That Closed-Form Doesn't)

### Full Distribution Over the Uncertainty Set

**Sampling approach** (M=2000 innovations):
```r
# Generate M distributions Q_m in B_λ(P₀)
innovations <- rdirichlet(M, rep(1, J))
phi_values <- numeric(M)

for (m in 1:M) {
  q_m <- (1 - lambda) * p0 + lambda * innovations[m, ]
  phi_values[m] <- compute_functional(q_m, data)
}

# Now we have DISTRIBUTION of φ(Q) over Q ∈ B_λ(P₀)
```

**What this enables:**

1. **Minimum (worst-case):** `min(phi_values)` ← Our primary focus
2. **Mean (typical case):** `mean(phi_values)`
3. **Median:** `median(phi_values)`
4. **Quantiles:**
   - 5th percentile: `quantile(phi_values, 0.05)`
   - 25th percentile: `quantile(phi_values, 0.25)`
5. **Variance/Spread:** How much does φ vary across ball?
6. **Maximum (best-case):** `max(phi_values)` ← Optimistic bound
7. **Full density:** `density(phi_values)` ← Shape of distribution

### Risk Profiles and Decision-Making

**Example: Different risk attitudes**

```r
# Conservative decision-maker: focus on 5th percentile
conservative <- quantile(phi_values, 0.05)

# Moderate decision-maker: focus on 25th percentile
moderate <- quantile(phi_values, 0.25)

# Risk-neutral: focus on mean
risk_neutral <- mean(phi_values)

# Optimistic: focus on median or 75th percentile
optimistic <- quantile(phi_values, 0.75)
```

**Interpretation:**
- **Spread is narrow** → Robust conclusion (φ stable across ball)
- **Spread is wide** → Sensitive to distributional shifts
- **Shape matters** → Skewed distribution = asymmetric risk

### Uncertainty Quantification

**How much does surrogate quality vary under uncertainty?**

```r
# Standard deviation of φ across ball
sd_phi <- sd(phi_values)

# Interquartile range
iqr_phi <- IQR(phi_values)

# Coefficient of variation
cv <- sd_phi / mean(phi_values)

# Interpretation:
# - Small CV → Surrogate quality stable (robust)
# - Large CV → Surrogate quality varies greatly (fragile)
```

---

## What Closed-Form Gives Us (That Sampling Doesn't)

### Point Estimates Only

**Closed-form approach:**
```r
# TV-ball minimum (instant)
phi_star <- sum(p0 * h) - lambda * max(abs(h))

# Wasserstein minimum (1-parameter optimization)
phi_star <- wasserstein_concordance_dual(...)$phi_star
```

**What we get:**
1. **Minimum (worst-case):** φ* = inf_{Q∈B} φ(Q) ✓
2. **Maximum (for maximization):** φ* = sup_{Q∈B} φ(Q) ✓

**What we DON'T get:**
- Mean, median, quantiles ✗
- Variance, spread ✗
- Full distribution ✗
- Risk profiles ✗

### But: Computational Efficiency

**Trade-off:**
- **Closed-form:** 4ms, only min/max
- **Sampling:** 38-1963ms, full distribution

**Speedup:** 10-500x faster, but less information

---

## When Does This Matter?

### Scenario 1: Worst-Case Decision-Making (Closed-Form Sufficient)

**Use case:** Regulatory approval, high-stakes decisions

**Question:** "Is the surrogate good enough even in worst-case?"

**Decision rule:**
```r
phi_star <- surrogate_inference_minimax(data, lambda=0.3,
                                        functional_type="concordance")$phi_star

if (phi_star > threshold) {
  decision <- "Approve surrogate (robust guarantee)"
} else {
  decision <- "Reject (fails worst-case test)"
}
```

**Closed-form is perfect:** Only need worst-case, get it instantly.

### Scenario 2: Risk Profiling (Need Sampling)

**Use case:** Portfolio of trials, risk management

**Question:** "How variable is surrogate performance under uncertainty?"

**Analysis:**
```r
# Need full distribution
result <- surrogate_inference_minimax(data, lambda=0.3,
                                      functional_type="correlation",
                                      n_innovations=2000)

phi_values <- result$all_schemes$quantiles$effects
phi_dist <- apply(phi_values, 1, function(e) cor(e[,1], e[,2]))

# Risk profile
risk_profile <- tibble(
  worst_case = min(phi_dist),
  percentile_5 = quantile(phi_dist, 0.05),
  percentile_25 = quantile(phi_dist, 0.25),
  median = median(phi_dist),
  mean = mean(phi_dist),
  sd = sd(phi_dist)
)
```

**Need sampling:** Closed-form insufficient.

### Scenario 3: Sensitivity Analysis (Hybrid Best)

**Use case:** Explore λ ∈ [0.1, 0.5]

**Approach 1: Closed-form only (fast but limited)**
```r
lambda_grid <- seq(0.1, 0.5, by = 0.05)

# Fast screening: worst-case only
worst_case <- map_dbl(lambda_grid, ~{
  surrogate_inference_minimax(data, lambda=.x,
                              functional_type="concordance")$phi_star
})
# Time: ~40ms total
```

**Approach 2: Sampling (slow but rich)**
```r
# Full distribution for selected λ
distributions <- map(c(0.1, 0.3, 0.5), ~{
  result <- surrogate_inference_minimax(data, lambda=.x,
                                        functional_type="correlation",
                                        n_innovations=2000)
  # Extract distribution
  ...
})
# Time: ~120ms total
```

**Approach 3: Hybrid (best of both)**
```r
# 1. Screen with concordance (fast)
lambda_grid <- seq(0.1, 0.5, by = 0.05)
worst_case <- map_dbl(lambda_grid, ~{
  surrogate_inference_minimax(data, lambda=.x,
                              functional_type="concordance")$phi_star
})

# 2. Identify critical λ values
critical_lambdas <- lambda_grid[worst_case < threshold + margin]

# 3. Detailed analysis at critical points only
if (length(critical_lambdas) > 0) {
  distributions <- map(critical_lambdas, ~{
    surrogate_inference_minimax(data, lambda=.x,
                                functional_type="correlation",
                                n_innovations=2000)
    # Full distribution
  })
}
```

**Hybrid is optimal:** Fast screening + targeted depth.

---

## Characterizing Distribution Analytically (Partial Solution)

### For TV-Ball: Extreme Points

**Theoretical insight:** The TV-ball in type space is a polytope. Extrema occur at vertices.

**What we can compute analytically:**

1. **Minimum:** φ* = E_P0[h] - λ·||h||∞ ✓ (closed-form)

2. **Maximum:** φ^max = E_P0[h] + λ·||h||∞ ✓ (closed-form for linear)

3. **Range:** [φ*, φ^max] ✓

**What we can't compute analytically:**
- Mean over ball ✗ (requires integration)
- Median ✗
- Variance ✗
- Arbitrary quantiles ✗

### For Wasserstein Ball: Harder

**Challenge:** Wasserstein ball is not a polytope in general.

**What we can compute:**
1. **Minimum:** Via dual optimization ✓
2. **Maximum:** Via dual optimization (flip sign) ✓

**What's hard:**
- Interior points require sampling ✗
- No simple characterization of "typical" Q ✗

---

## Hybrid Implementation Strategy

### Recommended Approach

```r
#' Minimax Inference with Optional Distribution
#'
#' @param data Data frame
#' @param lambda TV-ball radius
#' @param functional_type "concordance" or "correlation"
#' @param compute_distribution Logical: compute full distribution?
#' @param n_innovations If compute_distribution=TRUE, how many samples?
#'
#' @return List with:
#'   - phi_star: worst-case (always computed)
#'   - phi_distribution: full distribution (if requested)
#'   - phi_mean, phi_median, phi_quantiles: summaries (if requested)
surrogate_inference_minimax_hybrid <- function(
  data,
  lambda,
  functional_type = c("concordance", "correlation"),
  compute_distribution = FALSE,
  n_innovations = 2000
) {

  functional_type <- match.arg(functional_type)

  # Always compute worst-case
  if (functional_type == "concordance" && !compute_distribution) {
    # FAST PATH: Closed-form minimum only
    result <- list(
      phi_star = compute_concordance_minimax_closed_form(data, lambda)
    )

  } else {
    # SAMPLING PATH: Full distribution
    # (Required for correlation OR if user wants distribution)
    innovations <- MCMCpack::rdirichlet(n_innovations, rep(1, J))
    phi_values <- numeric(n_innovations)

    for (m in 1:n_innovations) {
      q_m <- (1 - lambda) * p0 + lambda * innovations[m,]
      phi_values[m] <- compute_functional(q_m, data, functional_type)
    }

    # Compute all summaries
    result <- list(
      phi_star = min(phi_values),  # Worst-case
      phi_distribution = phi_values,  # Full distribution
      phi_mean = mean(phi_values),
      phi_median = median(phi_values),
      phi_max = max(phi_values),
      phi_quantiles = quantile(phi_values, c(0.05, 0.25, 0.75, 0.95)),
      phi_sd = sd(phi_values)
    )
  }

  result
}
```

### Usage Examples

**Example 1: Fast screening (worst-case only)**
```r
result <- surrogate_inference_minimax_hybrid(
  data, lambda = 0.3,
  functional_type = "concordance",
  compute_distribution = FALSE  # Fast!
)
# Time: 4ms
# Get: phi_star only
```

**Example 2: Full risk profile**
```r
result <- surrogate_inference_minimax_hybrid(
  data, lambda = 0.3,
  functional_type = "concordance",
  compute_distribution = TRUE  # Compute distribution even for concordance
)
# Time: ~38ms (still faster than correlation!)
# Get: phi_star, mean, median, quantiles, variance, full distribution
```

**Example 3: Correlation (always gets distribution)**
```r
result <- surrogate_inference_minimax_hybrid(
  data, lambda = 0.3,
  functional_type = "correlation",
  compute_distribution = TRUE  # Implicit
)
# Time: ~38ms
# Get: Everything (correlation requires sampling anyway)
```

---

## Comparison Table: Information Content

| Summary | Closed-Form (Conc) | Sampling (Conc) | Sampling (Corr) |
|---------|-------------------|-----------------|-----------------|
| **Worst-case (min)** | ✓ Instant | ✓ From M samples | ✓ From M samples |
| **Mean** | ✗ | ✓ mean(φ_values) | ✓ mean(φ_values) |
| **Median** | ✗ | ✓ median(φ_values) | ✓ median(φ_values) |
| **Quantiles** | ✗ | ✓ quantile(φ_values) | ✓ quantile(φ_values) |
| **Variance** | ✗ | ✓ var(φ_values) | ✓ var(φ_values) |
| **Best-case (max)** | ✓ Analytical* | ✓ max(φ_values) | ✓ max(φ_values) |
| **Full density** | ✗ | ✓ density() | ✓ density() |
| **Time** | 4 ms ⭐ | 38 ms | 38 ms |

*For linear functionals: φ^max = E_P0[h] + λ·||h||∞

---

## When To Use Each Approach

### Use Closed-Form (Concordance, No Distribution)

**Scenarios:**
✓ Worst-case decision-making (regulatory approval)
✓ Large-scale screening (1000s of analyses)
✓ Real-time inference (<5ms required)
✓ Simple pass/fail criteria

**Limitation:** No risk profiling, no uncertainty quantification

**Decision rule:**
```r
if (only_need_worst_case && computational_efficiency_critical) {
  use_closed_form_concordance()
}
```

### Use Sampling (Get Distribution)

**Scenarios:**
✓ Risk profiling needed (variance, quantiles)
✓ Portfolio management (multiple studies)
✓ Sensitivity to distributional shape
✓ Publication (show full uncertainty)

**Cost:** 10-500x slower

**Decision rule:**
```r
if (need_risk_profile || need_quantiles || time_not_critical) {
  use_sampling_approach()
}
```

### Use Hybrid (Screen Then Sample)

**Scenarios:**
✓ Many λ values to explore (sensitivity analysis)
✓ Some λ values critical, others not
✓ Balance speed and depth

**Approach:**
```r
# 1. Screen all λ with closed-form (fast)
critical_lambdas <- identify_critical_lambdas_fast()

# 2. Deep dive at critical λ with sampling (rich)
detailed_results <- map(critical_lambdas, sample_distribution)
```

**Best of both worlds!**

---

## Extensions: Analytical Bounds on Distribution

### Can We Bound Distribution Properties?

**Question:** Without full sampling, can we bound mean/variance?

**For TV-Ball (Linear Functional):**

**Bounds on mean:**
```
E[φ(Q)] ∈ [φ*, φ^max]  (min, max)

But tighter bounds require sampling or additional assumptions.
```

**Bounds on variance:**
```
Var[φ(Q)] ≤ (φ^max - φ*)² / 4  (maximum variance)

But actual variance likely much smaller.
```

**Challenge:** Without sampling, can't determine where in these ranges we are.

### Approximate Distribution Via Moments

**Potential approach** (not yet implemented):

```r
# Compute analytically:
phi_min <- closed_form_minimum()
phi_max <- closed_form_maximum()

# Approximate distribution assuming uniform over [min, max]
# (Conservative assumption)
phi_mean_approx <- (phi_min + phi_max) / 2
phi_var_approx <- (phi_max - phi_min)^2 / 12

# Better: Assume beta or triangular distribution
# Requires mild assumptions about ball geometry
```

**Trade-off:** Approximate but fast vs Exact but slow.

---

## Recommendations for Manuscript

### Current Emphasis (Appropriate)

✓ Focus on worst-case (minimax)
✓ Closed-form for speed
✓ Sampling for validation

### Additional Discussion (Add)

**Subsection: "Distributional Information vs Point Estimates"**

> Sampling-based approaches provide the full distribution of φ(Q) over Q ∈ B_λ(P₀), enabling risk profiling (quantiles, variance) and portfolio decision-making. Closed-form solutions provide only worst-case bounds (minimum/maximum) but are 10-500× faster.
>
> For regulatory decisions requiring worst-case guarantees, closed-form concordance is ideal (4ms, only min/max needed). For risk management requiring uncertainty quantification (variance, 5th percentile, etc.), sampling approaches provide richer information at higher computational cost (38-1963ms).
>
> A hybrid strategy balances efficiency and depth: screen many λ values with closed-form (fast), then detailed distributional analysis at critical λ values (sampling). This enables comprehensive sensitivity analysis while maintaining computational feasibility.

### New Figure (Optional)

**Figure: Distribution of φ(Q) Across TV-Ball**

- Show density plots for sampling approach
- Mark min, 5th percentile, median, mean, max
- Compare narrow distribution (robust) vs wide (fragile)
- Demonstrate information gained from sampling

**Caption:**
> Distribution of correlation functional across TV-ball (λ=0.3) from M=2000 sampled distributions. Closed-form provides only minimum (red line); sampling provides full distribution enabling risk profiling. Narrow distribution indicates robust surrogate quality; wide distribution indicates sensitivity to distributional shifts.

---

## Bottom Line

### Trade-off Summary

| Aspect | Closed-Form | Sampling | Hybrid |
|--------|-------------|----------|--------|
| **Worst-case** | ✓ Instant | ✓ Slow | ✓ Instant |
| **Risk profile** | ✗ None | ✓ Full | ✓ Targeted |
| **Comp. time** | 4 ms | 38-1963 ms | 4-50 ms |
| **Use case** | Screening | Deep analysis | Both |

### Recommendation

1. **Default:** Closed-form for speed (worst-case sufficient for most decisions)

2. **When needed:** Add `compute_distribution = TRUE` for risk profiling

3. **Large studies:** Hybrid approach (screen → sample critical values)

4. **Manuscript:** Document trade-off, provide both options

### Implementation Priority

**High priority:**
- ✓ Closed-form already implemented and documented
- ☐ Document trade-off clearly (this file)
- ☐ Add `compute_distribution` parameter to API

**Medium priority:**
- ☐ Hybrid function implementation
- ☐ Examples in vignette

**Low priority:**
- ☐ Analytical bounds on mean/variance
- ☐ Distribution approximations

---

**Status:** Trade-off documented, hybrid approach designed
**Next:** Add `compute_distribution` parameter to package API
