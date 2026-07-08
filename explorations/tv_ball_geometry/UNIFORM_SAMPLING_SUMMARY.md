# Uniform Sampling from TV Ball: Hit-and-Run Implementation

**Date:** 2026-04-07
**Status:** Working implementation, validated

---

## Problem Statement

We need to uniformly sample from the TV ball:

$$B_\lambda(P_0) = \{Q : \text{TV}(Q, P_0) \leq \lambda\}$$

where $\text{TV}(Q, P_0) = \frac{1}{2}\sum_i |Q_i - P_{0,i}|$ and $Q, P_0$ are probability distributions.

**Challenge:** The TV ball is a convex polytope on the probability simplex. Uniform sampling requires specialized algorithms.

---

## Why Dirichlet Sampling is NOT Uniform

The existing approach samples:
1. $\lambda' \sim \text{Uniform}(0, \lambda)$
2. $\tilde{Q} \sim \text{Dirichlet}(\alpha, \ldots, \alpha)$
3. $Q = (1-\lambda')P_0 + \lambda'\tilde{Q}$

**This samples along rays from $P_0$**, not uniformly over the ball.

**Empirical evidence** (from `02_compare_samplers.R`):
- **Dirichlet:** Mean TV distance = 0.047 (stays near $P_0$)
- **Hit-and-Run:** Mean TV distance = 0.229 (explores full ball)
- Kolmogorov-Smirnov test: D = 0.947, p < 0.0001 (completely different)

---

## Hit-and-Run Algorithm

Hit-and-run is a Markov Chain Monte Carlo method that produces uniform samples from convex bodies.

### Algorithm

1. **Initialize:** Start at $q_0 = P_0$ (always feasible)

2. **For each iteration:**
   - Sample random direction $d$ on simplex tangent space
   - Find feasible segment: $\{q + td : t \in [t_{\min}, t_{\max}]\}$ such that
     - $q + td$ is a probability distribution (non-negative, sums to 1)
     - $\text{TV}(q + td, P_0) \leq \lambda$
   - Sample $t \sim \text{Uniform}(t_{\min}, t_{\max})$
   - Move to $q_{\text{new}} = q + td$

3. **Burn-in:** Discard first 500-1000 samples

4. **Thinning:** Keep every 5-10th sample to reduce autocorrelation

### Key Implementation Details

**Direction sampling:**
```r
# Sample on simplex tangent space (directions with sum = 0)
d <- rnorm(K)
d <- d - mean(d)  # Project onto tangent space
d <- d / sqrt(sum(d^2))  # Normalize
```

**Feasible range finding:**
- Check positivity: $q_i + td_i \geq 0$ for all $i$
- Check TV constraint: $\text{TV}(q + td, P_0) \leq \lambda$
- Use grid search over $t$ values (not elegant but works for exploration)

**Implementation:** See `01_hit_and_run_sampler.R`

---

## Validation Results

### Test 1: Basic Functionality (K=5, λ=0.3, n=500)

```
Acceptance rate: 100.00%
All samples sum to 1: TRUE
All samples non-negative: TRUE
All within TV ball: TRUE
TV distances - mean: 0.229, sd: 0.053, max: 0.300
```

✅ All samples are valid probability distributions in the TV ball

---

### Test 2: Comparison to Dirichlet (K=5, λ=0.3, n=1000)

| Method | Mean TV | SD TV | Interpretation |
|--------|---------|-------|----------------|
| Hit-and-Run | 0.229 | 0.051 | Explores full ball |
| Dirichlet (α=1) | 0.047 | 0.033 | Concentrates near $P_0$ |

**Statistical test:** KS D = 0.947, p < 0.0001

✅ Methods produce completely different distributions (as expected)

**Plots:** See `figures/compare_tv_distributions.pdf` and `figures/compare_2d_projection.pdf`

---

### Test 3: Convergence Diagnostics (4 chains, 500 samples each)

```
Gelman-Rubin R-hat: 1.0002
```

✅ Excellent convergence (want R-hat < 1.1, achieved < 1.01)

**Interpretation:** Chains from different starting points converge to same distribution quickly.

**Plots:** See `figures/convergence_trace.pdf`

---

### Test 4: Mixing Diagnostics (2000 samples, thin=1)

```
Effective sample size: 333 / 2000 = 16.67%
```

✅ Reasonable mixing for hit-and-run (typically 10-30% ESS)

**Interpretation:**
- Raw samples have autocorrelation (as expected for MCMC)
- Thinning by 5-10 gives quasi-independent samples
- For 10,000 raw iterations, we get ~1,667 effective samples

**Plots:** See `figures/autocorrelation.pdf`

---

## Recommended Usage

For the TV ball geometry analysis:

```r
# Load sampler
source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

# Setup
K <- 10  # Number of types
lambda <- 0.3  # TV ball radius
P0 <- rep(1/K, K)  # Baseline distribution

# Generate uniform samples
samples <- hit_and_run_tv_ball(
  P0 = P0,
  lambda = lambda,
  n_samples = 5000,  # Final samples
  burn_in = 1000,    # Discard initial samples
  thin = 10,         # Thinning interval
  verbose = TRUE
)

# Each row is a probability distribution Q in B_λ(P₀)
# samples is (5000 × K) matrix
```

**Time estimate:** ~2-3 minutes for 5000 samples with K=10, λ=0.3

---

## Comparison to Alternative Methods

| Method | Pros | Cons | Use Case |
|--------|------|------|----------|
| **Hit-and-Run** | Provably uniform, works for any convex body | Slower (~1000 iter/sec), requires tuning | Gold standard, formal analysis |
| **Dirichlet Ray** | Fast (~10000 iter/sec), simple | Not uniform, concentrates near $P_0$ | Quick exploration, not for uniform claims |
| **Rejection Sampling** | Simple, exact | Very inefficient in high dimensions | Only feasible for K ≤ 3 |
| **Gibbs Sampling** | Good for high-D | Requires conditional distributions | Not applicable here (TV constraint is global) |

---

## Limitations and Caveats

1. **Computational cost:** Hit-and-run is slower than Dirichlet sampling
   - ~1000 iterations/second vs ~10000 iterations/second
   - Need burn-in + thinning (multiply raw iterations by ~50-100)

2. **Dimension dependence:** Mixing slows in high dimensions
   - For K > 20, may need longer burn-in
   - ESS percentage decreases with K

3. **Feasible range finding:** Current implementation uses grid search
   - Not theoretically rigorous (but works in practice)
   - Could be improved with exact polytope methods (more complex)

4. **Warmup time:** First few samples are not uniform
   - Always use burn-in of at least 500-1000
   - Check convergence diagnostics for new settings

---

## When to Use Hit-and-Run vs Dirichlet

**Use Hit-and-Run when:**
- Need truly uniform sampling
- Making claims about "typical" behavior
- Comparing to theoretical uniform measures
- Publishing formal results

**Use Dirichlet when:**
- Quick exploration (not formal analysis)
- Consistent with minimax framework (uses Dirichlet)
- Computational budget is limited
- Mainly interested in near-$P_0$ behavior

**For this project:**
- Use **Hit-and-Run** for the geometry exploration (main analysis)
- Include **Dirichlet comparison** to show sensitivity to sampling
- Document both approaches in any writeup

---

## Files

- `01_hit_and_run_sampler.R` - Main implementation
- `02_compare_samplers.R` - Compare to Dirichlet
- `03_hit_and_run_diagnostics.R` - Convergence and mixing checks
- `figures/compare_tv_distributions.pdf` - Visual comparison
- `figures/convergence_trace.pdf` - Convergence diagnostic
- `figures/autocorrelation.pdf` - Mixing diagnostic

---

## References

**Hit-and-Run Sampling:**
- Smith (1984) "Efficient Monte Carlo Procedures for Generating Points Uniformly Distributed over Bounded Regions"
- Lovász & Vempala (2006) "Hit-and-run from a corner"

**TV Distance and Geometry:**
- Gibbs & Su (2002) "On choosing and bounding probability metrics"
- Tsybakov (2009) "Introduction to Nonparametric Estimation"

**MCMC Diagnostics:**
- Gelman & Rubin (1992) "Inference from iterative simulation using multiple sequences"
- Geyer (1992) "Practical Markov Chain Monte Carlo"

---

## Next Steps

Now that we have uniform sampling, we can proceed with the geometry analysis:

1. ✅ **Uniform sampling implemented** (this document)
2. → **Phase 1:** Core geometry analysis function
3. → **Phase 2:** Feature extraction
4. → **Phase 3:** Across-study correlation analysis
5. → **Phase 4:** Local geometry discovery

See `tv_ball_geometry_analysis.md` for full plan.
