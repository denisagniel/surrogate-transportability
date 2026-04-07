# TV Ball Geometry Analysis: Local Structure and Across-Study Patterns

**Status:** PLANNED
**Date:** 2026-04-07
**Threshold:** 60/100 (exploration mode)

---

## Research Questions

### Primary Questions

1. **Across-Study Correlation**: As study distributions Q vary within the TV ball B_λ(P₀), do the treatment effects ΔS(Q) and ΔY(Q) covary?
   - Differs from within-study correlation φ(Q) = Cor(ΔS, ΔY | Q)
   - Asks: "Do studies with high surrogate effects also have high outcome effects?"

2. **Local Geometry Discovery**: Are there identifiable subregions of B_λ where surrogate quality is systematically high?
   - Can we characterize these regions by features of Q?
   - What distribution characteristics predict good surrogate performance?

3. **Structure vs. Worst-Case**: How does the typical/structured behavior differ from the minimax bounds?
   - Minimax gives worst-case: inf φ(Q)
   - Exploration seeks: where is φ(Q) actually high?

### Secondary Questions

4. How does the across-study correlation depend on λ (TV ball radius)?
5. How does it depend on the sampling distribution (Dirichlet concentration α)?
6. Can we predict φ(Q) from observable features of Q?
7. Are patterns consistent across different functionals (correlation, PPV, concordance)?

---

## Contrast with Existing Implementation

### What We Currently Have (Minimax Framework)

```r
# For each Q sampled:
phi_m <- within_study_correlation(Q_m)

# Then:
phi_min <- min(phi_m)  # Worst-case bound
phi_max <- max(phi_m)  # Best-case bound
```

**Focus:** Adversarial, conservative bounds
**Output:** Two numbers (lower and upper bounds)

### What This Exploration Adds (Geometry Analysis)

```r
# Collect joint information:
for (Q_m in samples) {
  Delta_S_m <- mean_treatment_effect_S(Q_m)
  Delta_Y_m <- mean_treatment_effect_Y(Q_m)
  phi_m <- within_study_correlation(Q_m)
  features_m <- extract_features(Q_m)
}

# Analyze structure:
cor(Delta_S, Delta_Y)  # Across studies
clusters <- find_geometries(features, phi)
model <- predict_phi_from_features(features, phi)
```

**Focus:** Exploratory, discovering patterns
**Output:** Rich characterization of TV ball structure

---

## Implementation Plan

### Phase 1: Core Function (Est. 2-3 hours)

**File:** `explorations/tv_ball_geometry/01_core_geometry_analysis.R`

**Deliverable:** `analyze_tv_ball_geometry()` function

```r
analyze_tv_ball_geometry <- function(
  current_data,
  lambda = 0.3,
  M = 5000,           # Many samples to explore structure
  n_future = 500,     # Study size for each Q
  alpha = 1,          # Dirichlet concentration
  functionals = c("correlation", "ppv", "concordance"),
  seed = NULL
) {
  # Returns: tibble with M rows, columns:
  #   - m: sample index
  #   - Delta_S, Delta_Y: average treatment effects
  #   - phi_correlation, phi_ppv, phi_concordance: within-study
  #   - tv_to_P0: distance to baseline
  #   - entropy: -sum(Q log Q)
  #   - max_mass: max(Q)
  #   - gini: concentration index
  #   - Q_data: nested list column with full Q (optional)
}
```

**Key steps:**
1. Generate M samples Q₁, ..., Q_M from innovation mechanism
2. For each Q_m:
   - Generate study data from Q_m (n_future units)
   - Estimate ΔS(Q_m), ΔY(Q_m) via sample averages
   - Compute φ(Q_m) for each functional
   - Extract distribution features (entropy, max_mass, etc.)
3. Return combined tibble

**Implementation notes:**
- Use existing `generate_future_study()` infrastructure
- Leverage type-based estimation for treatment effects
- Add error handling for estimation failures

---

### Phase 2: Feature Engineering (Est. 1-2 hours)

**File:** `explorations/tv_ball_geometry/02_feature_extraction.R`

**Deliverable:** `extract_Q_features()` function

Features to extract from distribution Q:

**Basic:**
- `tv_to_P0`: Total variation distance to baseline
- `max_mass`: max_i Q[i] (concentration on single type)
- `entropy`: Shannon entropy -Σ Q[i] log Q[i]

**Distributional:**
- `gini`: Gini coefficient (inequality measure)
- `effective_types`: exp(entropy) (approximate number of "active" types)
- `mass_top3`: sum of top 3 probabilities

**Relative to P₀:**
- `kl_to_P0`: KL divergence to baseline
- `mass_shift_up`: sum of (Q[i] - P₀[i])₊ (mass moved up)
- `mass_shift_down`: sum of (P₀[i] - Q[i])₊ (mass moved down)
- `correlation_with_P0`: correlation between Q and P₀ vectors

**Moment-based:**
- `mean_type`: weighted average type index
- `sd_type`: standard deviation of type index

**Output:** Tibble with one row per Q, columns for each feature

---

### Phase 3: Across-Study Analysis (Est. 2 hours)

**File:** `explorations/tv_ball_geometry/03_across_study_correlation.R`

**Deliverable:** `analyze_across_study_correlation()` function

```r
analyze_across_study_correlation <- function(
  geometry_data,  # Output from analyze_tv_ball_geometry()
  by_functional = TRUE
) {
  # For each functional:
  #   1. Scatter plot: Delta_S vs Delta_Y
  #   2. Compute correlation + CI
  #   3. Test: is correlation significantly > 0?
  #   4. Compare to within-study phi distribution

  # Returns: list with
  #   - correlations: tibble of estimates + CIs
  #   - plots: list of ggplot objects
  #   - tests: hypothesis test results
}
```

**Analyses:**
1. **Overall across-study correlation**: cor(ΔS, ΔY) across all M samples
2. **Bootstrap CI**: Use bootstrap for uncertainty
3. **Comparison**: Plot across-study cor vs. distribution of within-study φ
4. **By functional**: Separate analysis for each functional
5. **Sensitivity to α**: How does correlation change with Dirichlet concentration?

**Plots:**
- Scatter: ΔS vs ΔY with regression line
- Density overlay: across-study cor vs. within-study φ distribution
- Faceted by functional

---

### Phase 4: Local Geometry Discovery (Est. 3-4 hours)

**File:** `explorations/tv_ball_geometry/04_find_local_geometries.R`

**Deliverable:** `discover_local_geometries()` function

**Approach A: Clustering in Feature Space**

```r
discover_local_geometries <- function(
  geometry_data,
  n_clusters = 3:6,  # Try different numbers
  features = c("entropy", "max_mass", "tv_to_P0", "Delta_S", "Delta_Y"),
  method = "mclust"  # or "kmeans", "hclust"
) {
  # 1. Extract feature matrix
  # 2. Standardize features
  # 3. Cluster using mclust (model-based clustering)
  # 4. For each cluster: summarize phi distribution
  # 5. Identify "good geometry" clusters (high median phi)

  # Returns: list with
  #   - clusters: cluster assignments
  #   - summaries: mean phi by cluster
  #   - characteristics: mean features by cluster
  #   - plots: visualization of clusters
}
```

**Clustering methods to try:**
- Model-based (mclust): Finds natural groupings
- K-means: Simple, interpretable
- Hierarchical: Shows nested structure

**Cluster characterization:**
- For each cluster: mean/median φ, ΔS, ΔY, and all features
- Statistical test: do clusters differ significantly in φ?
- Effect size: how much better is φ in "good" clusters?

**Visualization:**
- PCA/UMAP projection colored by cluster
- PCA/UMAP colored by φ value
- Parallel coordinates plot showing feature profiles
- Boxplots: φ distribution by cluster

---

**Approach B: Regression/Prediction**

```r
predict_phi_from_features <- function(
  geometry_data,
  functional = "correlation",
  method = "elastic_net"  # or "random_forest", "gam"
) {
  # Predict φ(Q) from features of Q
  # Identify which features matter most

  # Returns:
  #   - model: fitted model object
  #   - importance: variable importance rankings
  #   - performance: R², RMSE, etc.
  #   - partial_plots: marginal effects of key features
}
```

**Models to try:**
- Linear regression (interpretable baseline)
- Elastic net (feature selection)
- Random forest (nonlinear, interactions)
- GAM (smooth nonlinear effects)

**Interpretation:**
- Which features predict high φ?
- Are effects linear or nonlinear?
- Any interactions? (e.g., high entropy × low TV distance)

---

**Approach C: Subregion Comparison**

```r
compare_subregions <- function(
  geometry_data,
  regions = list(
    "low_tv" = tv_to_P0 < 0.2,
    "high_entropy" = entropy > 2.0,
    "concentrated" = max_mass > 0.5,
    ...
  )
) {
  # Compare phi across pre-defined regions
  # Test differences
  # Visualize
}
```

---

### Phase 5: Comprehensive Analysis Script (Est. 2 hours)

**File:** `explorations/tv_ball_geometry/05_run_full_analysis.R`

End-to-end script that:
1. Loads package and data
2. Runs geometry analysis (Phase 1)
3. Extracts features (Phase 2)
4. Analyzes across-study correlations (Phase 3)
5. Discovers local geometries (Phase 4)
6. Generates comprehensive report with plots
7. Saves results

**Parameters to vary:**
- λ ∈ {0.1, 0.3, 0.5}
- α ∈ {0.1, 1, 10} (Dirichlet concentration)
- N_baseline ∈ {100, 500, 1000}

**Output:**
- `explorations/tv_ball_geometry/results/geometry_analysis_YYYYMMDD.rds`
- `explorations/tv_ball_geometry/figures/` (15-20 plots)
- `explorations/tv_ball_geometry/report_YYYYMMDD.html` (R Markdown summary)

---

### Phase 6: Interpretation and Writing (Est. 2-3 hours)

**File:** `explorations/tv_ball_geometry/06_interpretation.md`

**Deliverable:** Written interpretation addressing:

1. **Main findings:**
   - Is across-study correlation positive? How strong?
   - Are there identifiable local geometries with high φ?
   - What features characterize good regions?

2. **Comparison to minimax:**
   - How far is median φ from worst-case φ_*?
   - How often is φ > 0.6 (or some threshold)?
   - Distribution vs. bounds

3. **Practical implications:**
   - Can we identify settings where surrogates work well?
   - Guidance for study design?
   - When to use vs. avoid surrogates?

4. **Methodological insights:**
   - Does sampling distribution (α) matter?
   - Role of λ in structuring the ball?
   - Consistency across functionals?

5. **Limitations:**
   - Depends on DGP choice
   - Dirichlet sampling vs. uniform over ball
   - Finite M sampling variability

6. **Next steps:**
   - Test on real data?
   - Compare to other surrogate validation approaches?
   - Develop formal theory for structure?

---

## Data Generating Process

For reproducibility, use the same DGP as main simulations:

```r
# Bivariate normal with correlation ρ
Sigma <- matrix(c(1, ρ, ρ, 1), 2, 2)
data <- MASS::mvrnorm(n, mu = c(0, 0), Sigma = Sigma)
S <- data[, 1]
Y <- data[, 2]

# Discretize into types
types <- cut(S, breaks = n_types)
```

**Vary ρ** to explore different degrees of true surrogate quality:
- ρ = 0.3: weak surrogate
- ρ = 0.5: moderate surrogate
- ρ = 0.7: strong surrogate

---

## Success Criteria (60/100 threshold)

Given exploration mode, success means:

**Minimum (must have):**
- ✓ Functions run without errors
- ✓ Across-study correlation computed
- ✓ At least one clustering method applied
- ✓ Basic visualizations generated

**Good (target):**
- ✓ All 4 phases implemented
- ✓ Multiple λ and α values tested
- ✓ Clear patterns identified (or null result documented)
- ✓ Plots publication-ready
- ✓ Written interpretation

**Excellent (aspirational):**
- ✓ Comprehensive analysis across DGPs
- ✓ Multiple clustering/prediction methods compared
- ✓ Formal statistical tests
- ✓ Connected to theory
- ✓ Draft of findings suitable for paper supplement

---

## File Structure

```
explorations/tv_ball_geometry/
├── README.md                          # This plan
├── 01_core_geometry_analysis.R        # Main function
├── 02_feature_extraction.R            # Feature engineering
├── 03_across_study_correlation.R      # Across-study analysis
├── 04_find_local_geometries.R         # Clustering/prediction
├── 05_run_full_analysis.R             # End-to-end script
├── 06_interpretation.md               # Written findings
├── results/                           # Generated data
│   ├── geometry_analysis_20260407.rds
│   └── cluster_results_20260407.rds
├── figures/                           # Generated plots
│   ├── across_study_scatter.pdf
│   ├── cluster_visualization.pdf
│   ├── feature_importance.pdf
│   └── ...
└── report_20260407.html               # R Markdown summary
```

---

## Key Design Decisions

### 1. Sampling Distribution

**Default: Dirichlet(1, ..., 1)** for consistency with minimax implementation

**Sensitivity analysis:** Try α ∈ {0.1, 1, 10} to understand dependence

**Limitation:** Results are specific to Dirichlet. Uniform over B_λ would be ideal but is hard to implement. Document this clearly.

### 2. Sample Size

**M = 5000** for rich exploration

**Trade-off:**
- Larger M: better coverage, more patterns
- Computational cost: ~20-30 min for full analysis
- Can start with M = 1000 for development

### 3. Features to Extract

Start with interpretable features (entropy, max_mass, TV distance)

Can add more sophisticated features if patterns unclear:
- Wasserstein distance to P₀
- Mixture components (if multimodal)
- Covariate shift patterns

### 4. Multiple Testing

With many comparisons, use:
- FDR correction for hypothesis tests
- Cross-validation for prediction models
- Permutation tests for cluster differences

---

## Connection to Existing Work

### Leverages Current Implementation

- Uses `generate_future_study()` from package
- Builds on TV distance infrastructure
- Consistent with DGPs from main simulations

### Differs from Minimax

- Not adversarial (exploratory)
- Not for bounds (for understanding)
- Not required for paper (supplement material)

### Potential Paper Contributions

If patterns are strong:
- **Main paper:** Brief discussion in Section 5 (empirical findings)
- **Supplement:** Full geometry analysis
- **Separate paper:** "Structure of TV balls for surrogate validation"

If patterns are weak:
- **Document null result:** "No clear local structure found"
- **Still valuable:** Shows minimax bounds are realistic

---

## Implementation Order

**Suggested sequence:**

1. **Start with Phase 1** (core function)
   - Get basic functionality working
   - Test with small M to verify correctness

2. **Quick Phase 3** (across-study correlation)
   - Easiest to interpret
   - Fast to implement
   - Tells you if structure exists

3. **Phase 2** (feature extraction) if patterns look promising

4. **Phase 4A** (clustering) if structure is clear

5. **Phase 4B** (prediction) for deeper dive

6. **Phases 5-6** (full analysis + interpretation) at end

---

## Questions to Resolve During Implementation

1. **How to handle estimation error?**
   - ΔS(Q), ΔY(Q) are estimated from finite samples
   - Bootstrap within each Q?
   - Or accept sampling variability?

2. **What defines a "good" geometry?**
   - Median φ > some threshold?
   - Relative to worst case?
   - Statistical significance?

3. **How to validate findings?**
   - Simulation with known structure?
   - Stability across seeds?
   - Consistency across DGPs?

4. **Which clustering method is best?**
   - May need to try several
   - Compare via silhouette scores
   - Interpretability matters

5. **How much does α matter?**
   - If results very sensitive, need to discuss
   - If robust, strengthens findings

---

## Dependencies

**R packages (already available):**
- surrogateTransportability (the package)
- dplyr, tidyr, purrr (data manipulation)
- ggplot2 (visualization)
- MASS (for mvrnorm)

**New packages needed:**
- mclust (model-based clustering)
- glmnet (elastic net)
- randomForest or ranger (random forest)
- mgcv (GAM)
- GGally (pairs plots)
- umap (dimension reduction)

**Install if needed:**
```r
install.packages(c("mclust", "glmnet", "ranger", "mgcv", "GGally", "umap"))
```

---

## Timeline Estimate

**Development time: 12-16 hours total**

- Phase 1: 2-3 hours
- Phase 2: 1-2 hours
- Phase 3: 2 hours
- Phase 4: 3-4 hours
- Phase 5: 2 hours
- Phase 6: 2-3 hours

**Could be split across:**
- Day 1: Phases 1-2 (core functionality)
- Day 2: Phase 3 (across-study analysis)
- Day 3: Phase 4 (geometry discovery)
- Day 4: Phases 5-6 (full analysis + writeup)

---

## References for Methods

**Clustering in distribution space:**
- Baharav et al. (2022) "Spectral clustering of Markov chain transition matrices"
- Carlsson (2009) "Topology and data" (TDA perspective)

**Feature-based analysis:**
- Zeevi et al. (2021) "Predictive inference with the jackknife+"
- Lei & Wasserman (2014) "Distribution-free prediction sets"

**Exploratory surrogate analysis:**
- VanderWeele (2013) "Surrogate measures and consistent surrogates"
- Joffe & Greene (2009) "Related causal frameworks"

---

## Notes for Implementation

1. **Start simple:** Get basic version working before adding complexity

2. **Validate incrementally:** Check each phase produces sensible results

3. **Document assumptions:** Especially about sampling and estimation

4. **Save intermediate results:** Don't recompute expensive steps

5. **Visualize early and often:** Plots reveal patterns code might miss

6. **Be prepared for null results:** Not finding structure is still informative

7. **Keep exploration mode mindset:** This is discovery, not hypothesis testing

---

## Decision Point

After Phase 3 (across-study correlation), evaluate:

**If across-study correlation is strong (>0.5):**
- → Proceed with geometry discovery (Phase 4)
- → Likely to find interpretable local structure
- → Good candidate for paper supplement

**If across-study correlation is weak (<0.3):**
- → May skip detailed geometry analysis
- → Document null finding
- → Confirms minimax approach is appropriate (no easy shortcuts)

**Either way is valuable scientifically!**

---

## Starting Point for Next Chat

When you start working on this, begin with:

```r
# Load package and set up
library(surrogateTransportability)
library(tidyverse)

# Source Phase 1 script
source("explorations/tv_ball_geometry/01_core_geometry_analysis.R")

# Run quick test with small M
test_results <- analyze_tv_ball_geometry(
  current_data = generate_study_data(n = 500),
  lambda = 0.3,
  M = 100,  # Small for testing
  n_future = 200
)

# Check structure
glimpse(test_results)

# Quick across-study correlation
cor(test_results$Delta_S, test_results$Delta_Y)
```

This will tell you immediately if the basic approach is working.
