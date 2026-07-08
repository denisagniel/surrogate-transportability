# Simulation Results Slides Implementation Summary

## Date: 2026-05-11

## What Was Done

Successfully replaced the "Two Approaches to Geometry" section (slides 21-24) with simulation validation results from the large-scale cluster study.

## Changes Made

### 1. Files Created

**Analysis Scripts:**
- `inst/presentation/load_simulation_results.R` - Extracts and summarizes simulation metrics from combined_results.rds
- `inst/presentation/create_simulation_figures.R` - Generates scatter plots for DGP 4 and DGP 5

**Figures:**
- `inst/presentation/figures/slide23_dgp4_perfect_correlation.png` - Shows ρ ≈ 1.0 despite PTE = 30%
- `inst/presentation/figures/slide24_dgp5_pte_undefined.png` - Shows ρ ≈ 1.0 when PTE = NaN

**Data:**
- `inst/presentation/key_metrics.rds` - Cached key metrics for all 4 DGPs

### 2. Files Modified

**Presentation:**
- `inst/presentation/slides.qmd` - Replaced slides 21-24 (geometry comparison) with 4 new simulation slides
- `inst/presentation/slides.html` - Rendered output

## New Slide Structure

### Slide 21: Large-Scale Validation (Setup)
- **Content:** Shared simulation design across all DGPs
- **Key details:** N = 10,000, M ≈ 2,100, 1,000 reps per DGP, λ = 0.3
- **Purpose:** Establish scale and purpose (validate theory with high-quality estimates)

### Slide 22: Validation: DGPs 1-2 (Brief)
- **Content:** Quick summary showing both methods work as expected
- **Results:** Bias < 0.04, Coverage 93-94%, theory confirmed
- **Message:** Baseline validation, move on to interesting cases

### Slide 23: DGP 4 - When Low PTE Hides Perfect Transportability
- **Setup:** Weak mediation (β_S = 0.3), strong direct effect (β_A = 0.7)
- **Key contrast:** PTE = 30% says "weak surrogate" but ρ ≈ 1.0 says "perfect transportability"
- **Figure:** Scatter plot of (ΔS, ΔY) showing near-perfect linear relationship
- **Simulation results:** Bias < 0.001, Coverage = 99.8%
- **Message:** Low PTE ≠ poor surrogate when effects co-vary

### Slide 24: DGP 5 - When PTE Fails but Correlation Works
- **Setup:** Antisymmetric effects, symmetric P₀, ΔY(P₀) ≈ 0
- **Key contrast:** PTE = NaN (undefined) but ρ ≈ 1.0 (well-defined, perfect)
- **Figure:** Scatter plot showing perfect correlation despite PTE failure
- **Simulation results:** Bias < 0.001, Coverage = 99.9%
- **Message:** Correlation handles edge cases PTE cannot

## Simulation Results Summary

From 4,000 total replications (1,000 per DGP):

| DGP | True ρ | Mean ρ̂ | Bias | Coverage | True PTE | Key Finding |
|-----|--------|---------|------|----------|----------|-------------|
| 1 | 0.691 | 0.653 | -0.038 | 94.2% | 81.6% | Baseline: unbiased, correct coverage |
| 2 | -0.885 | -0.873 | +0.011 | 93.2% | 53.1% | Baseline: unbiased, correct coverage |
| 4 | 1.000 | 0.999 | -0.001 | 99.8% | 30.0% | Low PTE but perfect correlation |
| 5 | 1.000 | 1.000 | -0.000 | 99.9% | NaN | PTE undefined but correlation perfect |

## Figure Properties

Both scatter plots use:
- Dark blue background (#01364C) matching slide theme
- Light gray points (#F7F8F9) with transparency
- Yellow linear fit line (#FFD700)
- Yellow annotation box with ρ and PTE values
- Axes labeled ΔS(Q) and ΔY(Q)
- Title describing the key message

Generated via:
- Single replication with n = 10,000
- tv_ball_correlation_IF_adaptive() with λ = 0.3
- M ≈ 1,200 sampled studies (adaptive convergence)
- Seeds: 12345 (DGP 4), 12346 (DGP 5)

## Narrative Flow

**Original slides 21-24:** Technical comparison of X-level vs observation-level geometries
- Focused on methodological choices
- Important for methods audience but potentially distracting

**New slides 21-24:** Empirical validation from large-scale simulations
- Shows the method actually works on data
- Demonstrates cases where PTE misleads or fails
- Provides concrete evidence for the conceptual example on slide 13
- More compelling for applied audience

## Technical Details

**Data Generation:**
Uses the same DGP function as cluster scripts:
```r
generate_dgp_data(n, p_X, params, X_levels)
```

5-level discrete X: [-2, -1, 0, 1, 2] with probabilities from YAML

**Effect Structure:**
- S: (γ_A + γ_AX·X)·A + ε_S
- Y: (β_A + β_AX·X)·A + β_S·S + β_SX·S·X + ε_Y

**Correlation Computation:**
- Sample M distributions from TV ball
- Compute (ΔS(Q), ΔY(Q)) for each via importance weighting
- Estimate cor(ΔS, ΔY) across sampled studies
- Influence function-based inference

## Verification

✅ Presentation renders without errors
✅ Figures display correctly in slides
✅ Narrative flow is coherent
✅ Speaker notes provide context
✅ Total slide count: 24 slides (+ title + thanks = 26 total)
✅ Figures match slide theme colors

## Files to Add to Git

When ready to commit:
```bash
git add inst/presentation/slides.qmd
git add inst/presentation/slides.html
git add inst/presentation/load_simulation_results.R
git add inst/presentation/create_simulation_figures.R
git add inst/presentation/figures/slide23_dgp4_perfect_correlation.png
git add inst/presentation/figures/slide24_dgp5_pte_undefined.png
```

Optional (data products):
```bash
git add inst/presentation/key_metrics.rds
```

## Next Steps

1. Review slides in presentation mode
2. Practice speaker notes for new slides
3. Consider updating slide 13 (conceptual example) to reference "validated in simulation" pointing forward to slide 21
4. Optionally add transition between slide 20 (technical details) and slide 21 (validation)
