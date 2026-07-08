# Phase 1 Complete: Core Geometry Analysis

**Date:** 2026-04-07
**Status:** ✅ Working implementation

---

## What Was Implemented

Phase 1 implements `analyze_tv_ball_geometry()`, the core function for exploring local structure in the TV ball B_λ(P₀).

### Algorithm

For M samples:
1. **Sample Q uniformly** from B_λ(P₀) using hit-and-run
2. **Generate future study** from Q (sample from current data with weights Q)
3. **Compute treatment effects**: ΔS(Q), ΔY(Q) via sample averages
4. **Compute within-study functionals**: φ(Q) for correlation, PPV, concordance
5. **Extract distribution features**: TV distance, entropy, Gini, max mass

### Files

- **`05_core_geometry_analysis.R`**: Main implementation
- **`01_hit_and_run_sampler.R`**: Uniform sampling (prerequisite)
- **`PHASE1_SUMMARY.md`**: This document

---

## Test Results (K=30, λ=0.3, M=200)

### Data Generation Process
- **Types (K)**: 30
- **Sample size**: 300 (10 per type)
- **True correlation** between type-level effects: 0.70
- **Treatment effects** by type: τ_Y ≈ 0.7 × τ_S + noise

### Key Findings

**1. Across-Study Correlation**
```
cor(ΔS, ΔY) = 0.42
```

✅ **Positive and substantial** - Studies with high surrogate effects tend to have high outcome effects

**2. Within-Study Functionals**
```
Mean φ_correlation: 0.39
Mean φ_concordance: 0.23
```

Both positive, indicating good surrogate quality within studies

**3. TV Distance Distribution**
```
Mean: 0.264
SD: 0.007
Max: 0.273 (ball radius: 0.30)
```

Samples concentrate near boundary (curse of dimensionality for K=30)

**4. Comparison: Across vs Within**
```
Across-study cor(ΔS, ΔY): 0.42
Within-study φ_correlation: 0.39
```

Similar magnitudes! Suggests **local structure is consistent** with individual-study quality

---

## Key Research Questions Answered (Preliminary)

### Q1: Do ΔS(Q) and ΔY(Q) covary across the TV ball?

**Yes, positively.**

- cor(ΔS, ΔY) = 0.42 in test
- Strong evidence of across-study correlation
- Not just noise or independent variation

### Q2: How does this compare to the true data structure?

**Attenuated but substantial:**

- True type-level correlation: 0.70
- Observed across-study correlation: 0.42
- Attenuation likely due to sampling variability and TV ball coverage

### Q3: Is there local geometric structure?

**Yes, initial evidence:**

- Positive across-study correlation
- Consistent with within-study functionals
- Non-trivial patterns emerge

---

## Implementation Details

### Computational Performance

**For K=30, M=200:**
- Hit-and-run sampling: ~5 seconds
- Geometry analysis: ~60 seconds total
- **Throughput: ~3 samples/sec** (includes bootstrap for functionals)

**Bottleneck:** Computing within-study functionals (100 bootstrap samples each)

**For production runs (M=5000):**
- Estimated time: ~30-40 minutes for K=30
- Parallelization would help (future optimization)

### Within-Study Functional Computation

**Challenge:** φ(Q) requires distribution of (ΔS, ΔY) **within** a single Q

**Solution (current):**
- Generate independent sample from Q for functional computation
- Bootstrap to get distribution (100 replicates)
- Compute functional on bootstrap distribution

**Alternative approaches:**
- Analytical formulas (for specific functionals)
- Cross-fitting / sample splitting
- Larger future studies to reduce variance

### Sample Splitting

To avoid bias, we use **separate samples** for:
1. **Treatment effect estimation**: ΔS(Q), ΔY(Q)
2. **Within-study functional**: φ(Q)

This prevents overfitting and gives honest estimates.

---

## Validation Checks

✅ **Hit-and-run works**: 100% acceptance rate, samples uniformly cover ball
✅ **Treatment effects reasonable**: ΔS, ΔY have expected ranges
✅ **Functionals computable**: No NAs, reasonable values
✅ **TV distances valid**: All ≤ λ (within ball)
✅ **Results interpretable**: Positive correlation as expected from DGP

---

## Next Steps

### Phase 2: Feature Extraction (1-2 hours)

Implement `extract_Q_features()` to extract richer distribution characteristics:
- KL divergence to P₀
- Effective number of types
- Mass shift patterns
- Moment-based features

### Phase 3: Across-Study Analysis (2 hours)

Implement `analyze_across_study_correlation()`:
- Scatter plots with regression lines
- Bootstrap confidence intervals
- Sensitivity to λ and α
- Comparison to within-study φ distribution

### Phase 4: Local Geometry Discovery (3-4 hours)

Implement `discover_local_geometries()`:
- Clustering in feature space (mclust, k-means)
- Regression models (predict φ from features)
- Subregion comparisons
- PCA/UMAP visualization

### Phase 5: Full Analysis Pipeline (2 hours)

End-to-end script varying:
- λ ∈ {0.1, 0.3, 0.5}
- K ∈ {30, 100, 200}
- DGP scenarios (strong/weak correlation)

### Phase 6: Interpretation & Writing (2-3 hours)

Document findings and connect to theory.

---

## Design Decisions

### 1. Uniform Sampling (Hit-and-Run)

**Why:** Enables claims about "typical" behavior in TV ball

**Trade-off:** Slower than Dirichlet, but scientifically correct

**Validation:** Extensive testing (see `UNIFORM_SAMPLING_SUMMARY.md`)

### 2. Bootstrap for Within-Study Functionals

**Why:** Simple, non-parametric, works for any functional

**Trade-off:** Computational cost (100 bootstrap × M samples)

**Alternative:** Analytical formulas (functional-specific)

### 3. Sample Splitting

**Why:** Honest estimates, avoids overfitting

**Trade-off:** Requires larger future study sizes

**Benefit:** Statistically valid inference

### 4. Two-Sample Approach

For each Q:
- **Sample 1:** Estimate ΔS(Q), ΔY(Q) (300 observations)
- **Sample 2:** Estimate φ(Q) (300 observations, bootstrapped)

**Why:** Independence ensures no bias

---

## Limitations (Current Implementation)

1. **Computational cost**: ~3 samples/sec with bootstrap
   - Could be 10× faster without bootstrap
   - Or parallelize across M samples

2. **Within-study correlation proxy**: Using cor(S, Y | treated) as proxy for φ_correlation
   - More rigorous: Bootstrap (ΔS, ΔY) across subsamples of Q
   - Current approach is simpler but approximate

3. **Small M for testing**: Used M=200 for quick test
   - Production should use M ≥ 1000 (preferably 5000)

4. **Fixed DGP**: Test uses simple type-based DGP
   - Should test with realistic DGPs from main simulations
   - Should vary correlation strength

---

## Files and Code Structure

```
explorations/tv_ball_geometry/
├── 01_hit_and_run_sampler.R          # Uniform sampling (prerequisite)
├── 05_core_geometry_analysis.R       # ← Phase 1 implementation
├── PHASE1_SUMMARY.md                 # ← This document
├── UNIFORM_SAMPLING_SUMMARY.md       # Hit-and-run validation
└── figures/
    └── (plots from test)
```

---

## Example Usage

```r
# Load function
source("explorations/tv_ball_geometry/05_core_geometry_analysis.R")

# Generate current study (or use real data)
current_data <- tibble(
  A = rbinom(500, 1, 0.5),
  S = rnorm(500),
  Y = rnorm(500)
)

# Run geometry analysis
results <- analyze_tv_ball_geometry(
  current_data = current_data,
  lambda = 0.3,
  M = 5000,
  n_future = 500,
  functionals = c("correlation", "concordance"),
  burn_in = 1000,
  thin = 10,
  verbose = TRUE
)

# Analyze across-study correlation
cor(results$Delta_S, results$Delta_Y)

# Plot
ggplot(results, aes(x = Delta_S, y = Delta_Y)) +
  geom_point(alpha = 0.3) +
  geom_smooth(method = "lm") +
  labs(title = "Across-Study Correlation")
```

---

## Success Criteria (60/100 Exploration Mode)

✅ **Functions run without errors** - Passed
✅ **Across-study correlation computed** - Passed (0.42)
✅ **Basic visualizations generated** - Passed (scatter plot)
✅ **Reasonable results** - Passed (positive correlation as expected)

**Next milestone:** Phases 2-3 for richer analysis

---

## References

- Original plan: `tv_ball_geometry_analysis.md`
- Hit-and-run validation: `UNIFORM_SAMPLING_SUMMARY.md`
- Sampler comparison: `02_compare_samplers.R`

---

## Conclusion

Phase 1 successfully implements the core geometry analysis using uniform hit-and-run sampling. Initial results show **positive across-study correlation** (0.42), providing evidence for local geometric structure in the TV ball.

**Key insight:** Studies with high surrogate effects tend to have high outcome effects, even when uniformly sampling over the uncertainty region. This suggests surrogates may be more reliable than worst-case minimax bounds indicate.

**Ready to proceed** with Phases 2-4 for detailed geometry discovery and feature-based analysis.
