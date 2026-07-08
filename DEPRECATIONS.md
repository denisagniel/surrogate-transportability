# Deprecation Roadmap: Aligning Package and Paper with Authoritative Slides

**Date:** 2026-05-01
**Status:** DRAFT - For Review
**Authority:** Presentation slides at `inst/presentation/slides.qmd` (22 slides, peer-reviewed)

---

## Executive Summary

The presentation slides represent the **authoritative, peer-reviewed vision** of the surrogate transportability method. This document identifies components in the paper and R package that should be deprecated, flagged as experimental, or clearly marked as non-core based on their absence from or conflict with the authoritative slides.

**Key Findings:**
- **6 functions** should be flagged as experimental (not core method)
- **3 paper sections** should be deprecated or moved to supplement
- **4 distance metrics** mentioned but not operationalized
- **2 computational approaches** not mentioned in slides but useful internally

---

## Core Method (FROM SLIDES - KEEP THESE)

### What the Slides Present as Core:

1. **Primary Functional:** Correlation between treatment effects `cor(ΔS, ΔY)`
2. **Secondary Functionals:** R-squared, MSPE (mentioned briefly as examples)
3. **Geometries:** X-level (compositional) vs Observation-level (general)
4. **Distance Metrics:** TV (total variation), Wasserstein (optimal transport)
5. **Sampling:** Hit-and-run MCMC for uniform distribution on geometry
6. **Inference:** Two-stage approach (AIPW + functional delta method)
7. **Restriction:** Absolute continuity (Q << P₀) as practical choice
8. **Comparisons:** Mediation/PTE, principal stratification, meta-analysis

---

## Category 1: DEPRECATE (Remove or Archive)

### Paper Components

#### 1. RF-Ensemble Discretization (Paper Section 9, ~70 pages)

**Location:** `inst/paper/main.tex` (likely lines 918-988 based on plan)
**Status:** DEPRECATE or move to online supplement
**Rationale:**
- Not mentioned in authoritative slides at all
- Adds 70+ pages of highly technical theory
- Not part of core message or method
- May be valuable for journal completeness but NOT the method

**Action:**
- [ ] Move to online supplement: `inst/paper/supplement_rf_ensemble.tex`
- [ ] Remove from main paper or reduce to 1-paragraph summary with "see supplement"
- [ ] Update references in main text

#### 2. Studies 2-3 Placeholders (Paper lines ~781-785)

**Status:** DEPRECATE or COMPLETE
**Rationale:**
- Marked as incomplete placeholders with bracketed descriptions
- Reduces paper credibility
- Not referenced in slides

**Action:**
- [ ] Either complete these simulation studies fully, OR
- [ ] Remove sections entirely and renumber remaining studies

#### 3. KL/Chi-squared/L2 Distance Metrics (Paper lines 96-99)

**Status:** FLAG AS FUTURE WORK (not deprecated, just not implemented)
**Rationale:**
- Mentioned in paper as potential metrics
- Never operationalized in package
- Not in slides (slides use only TV and Wasserstein)
- Creates expectation of functionality that doesn't exist

**Action:**
- [ ] Move discussion to "Future Directions" section
- [ ] Add note: "TV and Wasserstein are the operationalized metrics in this paper"
- [ ] Do NOT remove entirely (shows framework generality)

---

## Category 2: FLAG AS EXPERIMENTAL (Not Core Method)

### Package Functions to Flag

#### 1. Alternative Functionals: Concordance, PPV, NPV, Conditional Mean

**Files:** `R/surrogate_functionals.R`
**Functions:**
- `functional_concordance()` (lines 270-331)
- `functional_ppv()` (lines 208-267)
- `functional_npv()` (lines 334-394)
- `functional_conditional_mean()` (lines 126-206)

**Rationale:**
- **Concordance:** Linear functional enabling closed-form solutions, but NOT in slides
- **Conditional mean:** Explicitly removed from slides (not Hadamard differentiable)
- **PPV/NPV:** Never made it to authoritative presentation
- **Correlation is THE functional** per slides

**Action:**
- [ ] Add roxygen note to each function:
```r
#' @note This functional is not part of the core methodology presented in
#'   the main paper and authoritative presentation. Use
#'   \code{\link{functional_correlation}} for standard analysis. This function
#'   is provided for research purposes and alternative analyses.
#' @concept experimental
```
- [ ] Add lifecycle badge: `#' @keywords internal` or mark experimental
- [ ] Update `compute_all_functionals()` documentation to clarify hierarchy

#### 2. CATE Covariance Functional (Within-Study Paradigm)

**File:** `R/functional_cate_covariance.R` (entire file, 290 lines)
**Function:** `functional_cate_covariance()`

**Rationale:**
- Different conceptual framework: within-study heterogeneity vs across-study correlation
- Not mentioned in authoritative slides at all
- Could confuse users about what the method does
- Uses individual-level data, not study-level treatment effects

**Action:**
- [ ] Add prominent roxygen note:
```r
#' @note This implements an **alternative paradigm** (within-study CATE
#'   covariance) not presented in the main methodology. The core method
#'   focuses on **across-study** functionals like \code{\link{functional_correlation}}.
#'   Use this function only for specialized analyses examining treatment effect
#'   heterogeneity within a single study.
#' @section Alternative Paradigm:
#'   This is a **within-study** functional operating on individual-level data,
#'   distinct from the **across-study** functionals that are the focus of the
#'   surrogate transportability framework.
#' @concept experimental
#' @concept alternative-paradigm
```
- [ ] Consider separate vignette for alternative approaches
- [ ] Keep function but clearly mark as non-standard

#### 3. Bayesian Posterior Inference

**File:** `R/posterior_inference.R` (entire file, 599 lines)
**Functions:**
- `posterior_inference()`
- `posterior_inference_nested()`
- `compute_summary_stats()`
- `compute_summary_stats_nested()`
- `compare_surrogate_methods()`
- `plot_posterior()`

**Rationale:**
- Slides present frequentist delta method ONLY
- Bayesian approach not mentioned in authoritative presentation
- Could confuse users about inference approach

**Action:**
- [ ] Add roxygen note to main function:
```r
#' @note This implements **alternative Bayesian inference** using nested
#'   bootstrap. The main methodology presented in the paper uses frequentist
#'   functional delta method (see \code{\link{wasserstein_minimax_IF_inference}}).
#'   This function is provided for researchers preferring Bayesian paradigm.
#' @section Alternative Inference:
#'   The authoritative method uses two-stage functional delta method with
#'   influence function-based inference. This Bayesian approach is experimental.
#' @concept experimental
#' @concept bayesian
```
- [ ] Keep but mark as non-standard inference approach

#### 4. Sample-Splitting Minimax

**File:** Likely `R/sample_splitting_minimax_wasserstein.R`
**Function:** `sample_splitting_minimax_wasserstein()`

**Rationale:**
- Not in slides
- More advanced than basic method
- Post-selection bias correction not discussed in presentation

**Action:**
- [ ] Add roxygen note:
```r
#' @note This implements **advanced sample-splitting** to avoid post-selection
#'   bias when searching over lambda values. The basic method in the slides
#'   does not require sample splitting. Use this only for formal multiple
#'   testing correction across lambda grid.
#' @concept advanced
```
- [ ] Add lifecycle badge "experimental" or "maturing"

---

## Category 3: KEEP (Core Method - Already Aligned)

### Functions That Match Slides

**Keep these prominently featured:**

1. **`functional_correlation()`** - THE core functional
2. **`wasserstein_minimax_IF_inference()`** - Main inference function
3. **`generate_*()` functions** - Data generation infrastructure
4. **Distance computation utilities** - TV and Wasserstein only
5. **Traditional method wrappers:**
   - `compute_pte_standard()`
   - `compute_mediation_standard()`
   - `compute_ps_standard()`

   These are comparison baselines (Slides 6-8), NOT alternatives

---

## Category 4: INTERNAL (Keep But Document as Internal)

### Type-Level Discretization (Computational Optimization)

**Files:** Likely in `R/discretization.R` or similar
**Functions:**
- `discretize_data()`
- `compute_type_centroids()`
- Related type-level utilities

**Rationale:**
- Computational optimization (9x, 487x speedups per plan)
- Not conceptual mismatch, just implementation detail
- Slides don't mention but paper documents performance gains

**Action:**
- [ ] Mark functions as internal: `#' @keywords internal`
- [ ] Don't export or minimize user-facing documentation
- [ ] Keep for computational efficiency
- [ ] Add comment: "Internal utility for computational optimization"

---

## Paper Alignment Tasks

### Task 1: Strengthen X-Level vs Obs-Level Framing

**Current State:** Paper emphasizes TV vs Wasserstein
**Needed:** Paper should emphasize X-level vs Obs-level (slides' main distinction)

**Action:**
- [ ] Add explicit section: "Two Approaches to Geometry"
- [ ] Frame X-level as "compositional transportability"
- [ ] Frame Obs-level as "robust but conservative"
- [ ] Clarify these are complementary analyses (report both)

### Task 2: Add Simulation Matching Slides' PTE Example

**Current State:** Paper Study 1 focuses on classification accuracy (71% vs 38-49%)
**Needed:** Add scenario matching slides' opposite-signed interactions example

**Slides Example (Slide 13):**
- PTE = 0.54 in P₀ → "Good surrogate!" ✓
- Cor(ΔS, ΔY) = 0.00 across studies → "Won't transport" ✗

**Action:**
- [ ] Add new simulation scenario with effect modification in opposite directions
- [ ] Show ΔS increases with covariate, ΔY decreases with covariate
- [ ] Demonstrate PTE misleads when there's opposite-signed heterogeneity
- [ ] Include scatter plot colored by covariate (like Slide 13 figure)

### Task 3: Streamline Functional Presentation

**Action:**
- [ ] Lead with correlation as PRIMARY functional
- [ ] Mention R-squared and MSPE briefly as examples
- [ ] Remove or minimize concordance/PPV/NPV/conditional mean from main text
- [ ] If keeping alternatives, move to "Extensions" section and clearly mark non-core

### Task 4: Update README and Primary Vignette

**README.md:**
- [ ] Link to authoritative slides prominently
- [ ] Focus entirely on correlation functional
- [ ] Show X-level vs Obs-level comparison workflow
- [ ] Remove mentions of alternative functionals

**Primary Vignette:**
- [ ] Walk through slides' workflow exactly:
  1. Generate study data
  2. Compute correlation functional across lambda values
  3. Compare X-level vs Obs-level results
  4. Plot correlation vs lambda
  5. Interpret: flat = robust, steep = fragile
- [ ] No mention of alternative functionals in main vignette

---

## Migration Timeline

### Priority 1 (Critical for Consistency)
**Deadline:** Before next paper submission

- [ ] Add experimental notes to concordance, PPV, NPV, conditional mean functions
- [ ] Add alternative paradigm note to CATE covariance function
- [ ] Complete or remove Studies 2-3 from paper
- [ ] Update README to match slides

### Priority 2 (Important for Alignment)
**Deadline:** Before preprint posting

- [ ] Strengthen X-level vs Obs-level framing in paper
- [ ] Add PTE misleading simulation scenario
- [ ] Move RF-ensemble to supplement
- [ ] Update primary vignette to match slides workflow
- [ ] Add experimental note to posterior_inference()

### Priority 3 (Polish)
**Deadline:** Before final submission

- [ ] Complete this DEPRECATIONS.md document
- [ ] Update NEWS.md with deprecation notices
- [ ] Add lifecycle badges throughout
- [ ] Create "alternative approaches" vignette for experimental functions
- [ ] Update all cross-references in documentation

---

## Documentation Standards

### Experimental Function Template

For functions NOT in core method:

```r
#' [Function Title]
#'
#' [Standard description]
#'
#' @note **Experimental:** This function is not part of the core methodology
#'   presented in the main paper (see `inst/presentation/slides.qmd`).
#'   For standard analysis, use \code{\link{functional_correlation}}.
#'
#' @section Status:
#'   This implements [alternative approach / experimental method / advanced technique]
#'   provided for research purposes. The authoritative method uses
#'   [core method reference].
#'
#' @concept experimental
#' @keywords [internal if truly internal, otherwise keep user-facing]
```

### Internal Function Template

For computational utilities:

```r
#' [Function Title]
#'
#' [Standard description]
#'
#' @details Internal utility for computational optimization. Not part of
#'   user-facing API.
#'
#' @keywords internal
#' @concept computational
```

---

## Verification Checklist

After implementing deprecations:

### Slides ↔ Paper Alignment
- [ ] Paper emphasizes same functionals as slides (correlation primary)
- [ ] Paper uses X-level/Obs-level terminology prominently
- [ ] Paper includes PTE misleading example matching slides
- [ ] Studies 2-3 completed or removed
- [ ] RF-ensemble moved to supplement or removed

### Slides ↔ Package Alignment
- [ ] Main exported functions match slides' presentation
- [ ] Alternative functionals clearly marked as experimental
- [ ] README and primary vignette match slides' workflow
- [ ] No conflicting documentation

### Internal Consistency
- [ ] All experimental functions documented consistently
- [ ] DEPRECATIONS.md complete
- [ ] NEWS.md documents deprecations and status changes
- [ ] Package passes R CMD check with no errors
- [ ] All examples run without confusion about what's "core"

---

## FAQ

### Q: Why deprecate functions that work?

**A:** We're not removing functionality, just clarifying hierarchy. The slides represent the peer-reviewed, authoritative vision. Functions not in slides should be clearly marked as "experimental" or "alternative" so users know what the core method is.

### Q: Can I still use concordance functional?

**A:** Yes! It's not being removed. But it will be documented as experimental and not part of the core methodology. Use it if you need linear functionals for closed-form solutions, but know it's not what the paper presents as the method.

### Q: What about CATE covariance?

**A:** It's a different paradigm (within-study vs across-study). We'll keep it but document clearly that it's an alternative approach, not the core surrogate transportability method.

### Q: Will posterior_inference() be removed?

**A:** No. It will be marked as alternative Bayesian inference. The core method uses frequentist functional delta method, but researchers preferring Bayesian approaches can use this.

### Q: Why is this important?

**A:** **Consistency.** When paper, package, and presentation tell different stories about what the method "is", it confuses users and reviewers. The slides are authoritative because they've been through peer review. We align everything to that vision.

---

## References

- **Authoritative Source:** `inst/presentation/slides.qmd` (22 slides)
- **Plan Source:** Deprecation identification plan (2026-05-01)
- **Constitution:** `meta-spec/RESEARCH_CONSTITUTION.md` (§9 design invariants, §11 anti-goals)

---

## Appendix: Function Status Summary

| Function | File | Status | Action |
|----------|------|--------|--------|
| `functional_correlation()` | `surrogate_functionals.R` | **CORE** | Keep prominent |
| `functional_concordance()` | `surrogate_functionals.R` | EXPERIMENTAL | Add note |
| `functional_ppv()` | `surrogate_functionals.R` | EXPERIMENTAL | Add note |
| `functional_npv()` | `surrogate_functionals.R` | EXPERIMENTAL | Add note |
| `functional_conditional_mean()` | `surrogate_functionals.R` | EXPERIMENTAL | Add note |
| `functional_probability()` | `surrogate_functionals.R` | SECONDARY | Keep but de-emphasize |
| `functional_cate_covariance()` | `functional_cate_covariance.R` | ALTERNATIVE PARADIGM | Add note |
| `posterior_inference()` | `posterior_inference.R` | ALTERNATIVE INFERENCE | Add note |
| `wasserstein_minimax_IF_inference()` | `wasserstein_minimax_IF_inference.R` | **CORE** | Keep prominent |
| `sample_splitting_minimax_wasserstein()` | (various) | ADVANCED | Add note |
| `discretize_data()` | (various) | INTERNAL | Mark internal |
| `compute_type_centroids()` | (various) | INTERNAL | Mark internal |
| `compute_pte_standard()` | `traditional_methods_standard.R` | **COMPARISON BASELINE** | Keep |
| `compute_mediation_standard()` | `traditional_methods_standard.R` | **COMPARISON BASELINE** | Keep |
| `compute_ps_standard()` | `traditional_methods_standard.R` | **COMPARISON BASELINE** | Keep |

---

**End of Deprecation Roadmap**
