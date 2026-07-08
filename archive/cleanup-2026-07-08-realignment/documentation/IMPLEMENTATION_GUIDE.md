# Implementation Guide: Deprecation and Alignment

**Date:** 2026-05-01
**Purpose:** Practical step-by-step guide for implementing deprecation roadmap

---

## Overview

This guide provides **concrete, actionable steps** with code examples for implementing the deprecation roadmap. Follow Priority 1 → Priority 2 → Priority 3.

---

## Priority 1: Critical for Consistency

### Task 1.1: Flag Concordance Functional as Experimental

**File:** `R/surrogate_functionals.R`
**Line:** 270 (function definition for `functional_concordance`)

**Current Code (line 270):**
```r
#' Compute concordance functional
```

**Add Before Documentation:**
```r
#' Compute concordance functional
#'
#' [Keep existing description lines 271-289]
#'
#' @note **Experimental:** This functional is not part of the core methodology
#'   presented in the main paper and authoritative presentation
#'   (see \code{inst/presentation/slides.qmd}). Use
#'   \code{\link{functional_correlation}} for standard analysis.
#'
#'   **Why concordance for computational optimization?**
#'   Unlike correlation, concordance is LINEAR in treatment effects, enabling
#'   closed-form solutions for distributional robustness optimization.
#'   This is a computational advantage but not a scientific justification
#'   for preferring concordance over correlation.
#'
#' @section Status:
#'   This implements an experimental functional provided for researchers
#'   interested in closed-form minimax solutions. The authoritative method
#'   uses correlation as the primary functional.
#'
#' @concept experimental
#' @keywords functional
```

**Verification:**
```r
# After editing, run:
devtools::document()
?functional_concordance  # Check help file shows note
```

---

### Task 1.2: Flag PPV Functional as Experimental

**File:** `R/surrogate_functionals.R`
**Line:** 208 (function definition for `functional_ppv`)

**Add to Documentation (after line 227):**
```r
#' @note **Experimental:** This functional is not part of the core methodology
#'   presented in the main paper. Use \code{\link{functional_correlation}}
#'   for standard analysis. PPV is provided for decision-theoretic analyses
#'   where binary classification (reject/don't reject) is the primary goal.
#'
#' @concept experimental
#' @concept decision-theory
```

---

### Task 1.3: Flag NPV Functional as Experimental

**File:** `R/surrogate_functionals.R`
**Line:** 334 (function definition for `functional_npv`)

**Add to Documentation (after line 357):**
```r
#' @note **Experimental:** This functional is not part of the core methodology
#'   presented in the main paper. Use \code{\link{functional_correlation}}
#'   for standard analysis. NPV complements PPV for complete decision-theoretic
#'   evaluation.
#'
#' @concept experimental
#' @concept decision-theory
```

---

### Task 1.4: Flag Conditional Mean Functional as Experimental

**File:** `R/surrogate_functionals.R`
**Line:** 126 (function definition for `functional_conditional_mean`)

**Add to Documentation (after line 143):**
```r
#' @note **Experimental:** This functional is not part of the core methodology
#'   presented in the main paper. It was explicitly removed from the
#'   authoritative presentation due to non-differentiability issues
#'   (indicators in denominator). Use \code{\link{functional_correlation}}
#'   for standard analysis.
#'
#'   **Technical limitation:** Conditional mean involves E[ΔY | ΔS = δ],
#'   which has indicators in denominator when estimated via kernel methods.
#'   This violates Hadamard differentiability, complicating inference.
#'
#' @concept experimental
#' @concept non-differentiable
```

---

### Task 1.5: Flag CATE Covariance as Alternative Paradigm

**File:** `R/functional_cate_covariance.R`
**Line:** 1 (function definition)

**Add After Existing @section Functional Paradigm (line 7):**
```r
#' @note **Alternative Paradigm:** This implements a **within-study** functional
#'   measuring CATE covariance, which is conceptually distinct from the
#'   **across-study** functionals that are the focus of the surrogate
#'   transportability framework.
#'
#'   The core methodology (see \code{inst/presentation/slides.qmd}) evaluates
#'   surrogate quality by examining correlation of study-level treatment effects
#'   **across** hypothetical future studies. This function instead examines
#'   correlation of individual-level treatment effects **within** a single study.
#'
#'   Use this function only for specialized analyses examining treatment effect
#'   heterogeneity within a single study. For standard surrogate transportability
#'   analysis, use \code{\link{functional_correlation}}.
#'
#' @section When to Use:
#'   - You want to measure treatment effect heterogeneity within one study
#'   - You have individual-level covariate data
#'   - You're interested in which individuals benefit most from treatment
#'
#' @section When NOT to Use:
#'   - You want to evaluate surrogate transportability across studies
#'   - You want to assess how surrogate quality varies with population shifts
#'   - You want the core methodology presented in the paper
#'
#' @concept experimental
#' @concept alternative-paradigm
#' @concept within-study
```

**Verification:**
```r
devtools::document()
?functional_cate_covariance  # Check both sections appear
```

---

### Task 1.6: Flag Posterior Inference as Alternative

**File:** `R/posterior_inference.R`
**Line:** 1 (main function definition)

**Add After Existing Documentation (before @param, around line 9):**
```r
#' @note **Alternative Inference:** This implements Bayesian inference using
#'   nested bootstrap. The core methodology presented in the paper and
#'   authoritative presentation uses **frequentist functional delta method**
#'   (see \code{\link{wasserstein_minimax_IF_inference}}).
#'
#'   **Core Method:**
#'   - Stage 1: AIPW for treatment effects (doubly robust)
#'   - Stage 2: Functional delta method for correlation
#'   - Inference: Influence function-based standard errors
#'
#'   **This Alternative:**
#'   - Stage 1: Bayesian bootstrap resampling
#'   - Stage 2: Nested resampling for future studies
#'   - Inference: Posterior quantiles
#'
#'   This function is provided for researchers preferring Bayesian paradigm
#'   or wanting to compare inference approaches.
#'
#' @section Status:
#'   Experimental. Not part of authoritative methodology.
#'   Use \code{\link{wasserstein_minimax_IF_inference}} for standard analysis.
#'
#' @concept experimental
#' @concept bayesian
#' @concept alternative-inference
```

---

### Task 1.7: Update README.md

**File:** `README.md`

**Current:** (Read first to see structure)
```bash
# Read current README
cat README.md
```

**Add at Top After Title:**
```markdown
## Overview

This package implements surrogate transportability analysis via local geometric
evaluation. The method evaluates how well a surrogate marker will perform in
future studies by examining correlation of treatment effects across hypothetical
future distributions.

**Authoritative Reference:** See `inst/presentation/slides.qmd` for the
peer-reviewed presentation of the core methodology.

**Core Method:**
- **Primary functional:** Correlation between treatment effects
- **Geometries:** X-level (compositional) vs Observation-level (general)
- **Metrics:** TV (total variation) and Wasserstein distance
- **Sampling:** Hit-and-run MCMC for uniform distribution on geometry
- **Inference:** Two-stage functional delta method (AIPW + delta method)
```

**Update "Quick Start" Example:**
```markdown
## Quick Start

### Basic Workflow (Matches Authoritative Presentation)

```r
library(surrogateTransportability)

# 1. Generate or load study data
current_data <- generate_study_data(n = 500)

# 2. Run surrogate transportability analysis
result <- wasserstein_minimax_IF_inference(
  data = current_data,
  lambda_values = seq(0.05, 0.20, by = 0.05),
  geometry = "X-level",
  n_samples = 500
)

# 3. Compare X-level vs Observation-level
result_obs <- wasserstein_minimax_IF_inference(
  data = current_data,
  lambda_values = seq(0.05, 0.20, by = 0.05),
  geometry = "observation-level",
  n_samples = 500
)

# 4. Plot correlation vs lambda
plot_correlation_vs_lambda(result, result_obs)

# 5. Interpret results
# - Flat line → Robust surrogate (works across populations)
# - Steep decline → Fragile surrogate (only works for similar populations)
# - X-level higher than Obs-level → Unmeasured heterogeneity matters
```
```

**Add Section on Alternative Functions:**
```markdown
## Alternative and Experimental Functions

The package includes additional functions beyond the core methodology for
research purposes. These are **not part of the authoritative method** presented
in `inst/presentation/slides.qmd`:

- **Alternative functionals:** `functional_concordance()`, `functional_ppv()`,
  `functional_npv()`, `functional_conditional_mean()`
  - Status: Experimental
  - Use for specialized analyses only

- **Within-study paradigm:** `functional_cate_covariance()`
  - Status: Alternative paradigm
  - Measures heterogeneity within study, not transportability across studies

- **Bayesian inference:** `posterior_inference()`
  - Status: Alternative inference
  - Core method uses frequentist functional delta method

See function documentation for details on when to use these alternatives.
```

---

### Task 1.8: Update Primary Vignette

**File:** `vignettes/introduction.Rmd` (or create if doesn't exist)

**Template Structure:**
```markdown
---
title: "Introduction to Surrogate Transportability"
author: "Daniel Agniel"
date: "`r Sys.Date()`"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Introduction to Surrogate Transportability}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r setup, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 7,
  fig.height = 5
)
library(surrogateTransportability)
```

## The Problem

Surrogate markers promise to accelerate research by replacing expensive outcomes
with cheaper alternatives. But will a surrogate validated in one study work in
**future studies** with different populations?

Traditional methods (mediation, PTE, principal stratification) **assume**
transportability. We **evaluate** it.

## The Method

### Step 1: Local Geometries

Instead of waiting for multiple studies, we consider **hypothetical future studies**
within distance λ of the current study:

U(P₀, λ) = {Q : distance(Q, P₀) ≤ λ}

### Step 2: Compute Correlation Across Studies

For each Q in the geometry, compute treatment effects ΔS(Q) and ΔY(Q).
Then compute:

Θ(λ) = cor(ΔS, ΔY) across Q ~ Uniform(U(P₀, λ))

### Step 3: Interpretation

- **Flat line** (correlation stable as λ increases): Robust surrogate
- **Steep decline** (correlation drops quickly): Fragile surrogate

## Quick Example

```{r example}
# Generate study data
set.seed(123)
current_data <- generate_study_data(
  n = 500,
  effect_size_s = 0.5,
  effect_size_y = 0.4,
  correlation = 0.8
)

# Run analysis over lambda grid
result <- wasserstein_minimax_IF_inference(
  data = current_data,
  lambda_values = seq(0.05, 0.20, by = 0.05),
  geometry = "X-level",
  n_samples = 500
)

# Plot results
plot_correlation_vs_lambda(result)
```

## X-Level vs Observation-Level

Two complementary approaches:

### X-Level (Compositional)
- Future studies differ in covariate distributions
- Assumes treatment effect functions transport
- Higher correlation (optimistic)
- Clear interpretation for population shifts

### Observation-Level (General)
- Future studies differ in individual composition
- Includes unmeasured heterogeneity
- Lower correlation (conservative)
- More robust but less interpretable

**Best Practice:** Report both.

```{r comparison}
# X-level analysis
result_x <- wasserstein_minimax_IF_inference(
  data = current_data,
  lambda_values = seq(0.05, 0.20, by = 0.05),
  geometry = "X-level",
  n_samples = 500
)

# Observation-level analysis
result_obs <- wasserstein_minimax_IF_inference(
  data = current_data,
  lambda_values = seq(0.05, 0.20, by = 0.05),
  geometry = "observation-level",
  n_samples = 500
)

# Compare
plot_correlation_vs_lambda(result_x, result_obs)
```

The gap between X-level and Obs-level indicates importance of unmeasured
heterogeneity.

## Alternative Functions

The package includes experimental functions not part of the core methodology:

- `functional_concordance()`: Linear functional for closed-form solutions
- `functional_cate_covariance()`: Within-study heterogeneity (different paradigm)
- `posterior_inference()`: Bayesian inference (alternative to frequentist)

See function documentation for when to use these alternatives.

## References

- Main paper: [Citation]
- Authoritative presentation: `inst/presentation/slides.qmd`
```

---

## Priority 2: Important for Alignment

### Task 2.1: Add PTE Misleading Example to Paper

**File:** `inst/paper/main.tex`

**Location:** Add new simulation scenario in simulation section

**Content to Add:**
```latex
\subsubsection{Scenario: When PTE Misleads Due to Opposite-Signed Interactions}

We demonstrate a scenario where traditional PTE analysis suggests a good surrogate,
but local geometric evaluation correctly identifies fragility.

\paragraph{Data generating process.}
Let $X \sim \text{Uniform}(0, 1)$ represent patient severity. Treatment effects
are modified by $X$ with \textbf{opposite signs}:
\begin{align*}
    \tau_S(X) &= 0.3 + 0.4X  \quad \text{(surrogate effect increases with severity)}\\
    \tau_Y(X) &= 0.5 - 0.4X  \quad \text{(outcome effect decreases with severity)}
\end{align*}

In the current study $\mathbb{P}_0$ with $X \sim \text{Uniform}(0,1)$:
\begin{itemize}
    \item Mean effects: $\Delta_S(\mathbb{P}_0) = 0.5$, $\Delta_Y(\mathbb{P}_0) = 0.3$
    \item Within-study mediation analysis yields PTE $\approx 0.54$
    \item Conclusion from traditional analysis: ``Decent surrogate''
\end{itemize}

\paragraph{Local geometric evaluation.}
We sample future studies $\mathcal{Q}$ from $U(\mathbb{P}_0, \lambda)$ using
X-level geometry (varying the distribution of $X$ while holding $\tau_S(X)$ and
$\tau_Y(X)$ fixed). As $\mathcal{Q}$ shifts toward higher or lower severity:
\begin{itemize}
    \item Studies with high mean($X$): Large $\Delta_S$, small $\Delta_Y$
    \item Studies with low mean($X$): Small $\Delta_S$, large $\Delta_Y$
    \item Correlation: $\text{cor}(\Delta_S, \Delta_Y) \approx 0.00$ across $\mathcal{Q}$
\end{itemize}

\paragraph{Results.}
Figure~\ref{fig:pte-misleading} shows the key finding: despite PTE = 0.54 in
$\mathbb{P}_0$, the correlation of treatment effects \textbf{across studies}
is essentially zero. The surrogate fails to transport because the effect
modifications operate in opposite directions. This is invisible to within-study
methods but immediately apparent from local geometric evaluation.

\begin{figure}[htbp]
\centering
\includegraphics[width=0.7\textwidth]{figures/pte_misleading_example.pdf}
\caption{Treatment effects across future studies (colored by mean severity).
    Despite PTE = 0.54 in current study, correlation across studies is zero.}
\label{fig:pte-misleading}
\end{figure}

\paragraph{Interpretation.}
This demonstrates the fundamental limitation of within-study surrogate evaluation:
when effect modification operates in opposite directions on $S$ and $Y$, a surrogate
that looks good in one population will fail to predict treatment effects in
populations with different covariate distributions. Local geometric evaluation
detects this fragility by explicitly examining variation across populations.
```

**Figure to Generate:**
```r
# Script: explorations/figures/generate_pte_misleading.R
library(tidyverse)
library(surrogateTransportability)

# DGP with opposite-signed interactions
set.seed(42)
n <- 1000
data <- tibble(
  X = runif(n, 0, 1),
  A = rbinom(n, 1, 0.5),
  tau_S = 0.3 + 0.4 * X,
  tau_Y = 0.5 - 0.4 * X,
  S = rnorm(n, mean = A * tau_S, sd = 0.5),
  Y = rnorm(n, mean = A * tau_Y, sd = 0.5)
)

# Run local geometric evaluation
result <- wasserstein_minimax_IF_inference(
  data = data,
  lambda_values = seq(0, 0.20, by = 0.02),
  geometry = "X-level",
  n_samples = 500,
  covariates = "X"
)

# Extract treatment effects and mean X for each sampled Q
effects <- extract_effects_by_study(result)

# Plot
p <- ggplot(effects, aes(x = delta_s, y = delta_y, color = mean_X)) +
  geom_point(alpha = 0.6, size = 2) +
  geom_smooth(method = "lm", se = FALSE, color = "black", linetype = "dashed") +
  scale_color_viridis_c(name = "Mean Severity", option = "plasma") +
  labs(
    x = expression(Delta[S](Q)~"(Surrogate Effect)"),
    y = expression(Delta[Y](Q)~"(Outcome Effect)"),
    title = "When PTE Misleads: Opposite-Signed Interactions",
    subtitle = sprintf("PTE in P₀ = 0.54  |  Correlation across studies = %.2f",
                      cor(effects$delta_s, effects$delta_y))
  ) +
  theme_minimal(base_size = 14)

ggsave("inst/paper/figures/pte_misleading_example.pdf", p, width = 8, height = 6)
```

---

### Task 2.2: Strengthen X-Level vs Obs-Level Framing in Paper

**File:** `inst/paper/main.tex`

**Location:** In "Local geometries" section (around line 83)

**Add New Subsection:**
```latex
\subsection{Two Complementary Approaches to Geometry}

A critical design choice is: \textbf{what space do we define $\mathcal{Q}$ over?}
Two natural approaches provide complementary evidence about surrogate transportability.

\subsubsection{X-Level (Compositional) Geometry}

The X-level approach defines $\mathcal{Q}$ over \textbf{covariate distributions}.
Future studies differ in their covariate mix---different proportions of elderly
patients, different baseline risk distributions, different demographic
compositions---but the treatment effect functions $\tau_S(X)$ and $\tau_Y(X)$
remain constant.

Formally, we define:
\begin{align}
    U_X(\mathbb{P}_0, \lambda; d) = \{\mathcal{Q}: \mathcal{Q} \text{ over } X,\, d(\mathcal{Q}_X, \mathbb{P}_{0,X}) \leq \lambda\}
\end{align}

\textbf{What varies:} $P(X)$ \\
\textbf{What's constant:} $\tau_S(X) = \mathbb{E}[S(1) - S(0) \mid X]$,
$\tau_Y(X) = \mathbb{E}[Y(1) - Y(0) \mid X]$

\textbf{Interpretation:} ``If a future study enrolls a different patient population
(different ages, different severities, different risk profiles), but the biological
mechanisms remain the same, how well does the surrogate transport?''

\textbf{Assumptions:}
\begin{itemize}
    \item $X$ captures all effect modifiers
    \item Treatment effect functions $\tau_S(X)$ and $\tau_Y(X)$ transport
    \item Surrogate-outcome relationship constant within covariate strata
\end{itemize}

When these assumptions hold, X-level geometry provides clear interpretation for
compositional transportability: correlation quantifies how robust the surrogate
is to changes in patient population mix.

\subsubsection{Observation-Level (General) Geometry}

The observation-level approach defines $\mathcal{Q}$ over \textbf{individuals}.
Future studies differ in their individual-level composition, including both
measured covariates $X$ and unmeasured heterogeneity $U$ and idiosyncratic
variation $\epsilon_i$.

Formally:
\begin{align}
    U_{\text{obs}}(\mathbb{P}_0, \lambda; d) = \{\mathcal{Q}: \mathcal{Q} \text{ over } (X, U, \epsilon),\, d(\mathcal{Q}, \mathbb{P}_0) \leq \lambda\}
\end{align}

\textbf{What varies:} Everything (covariates, unmeasured factors, noise) \\
\textbf{What's constant:} Nothing beyond observed data

\textbf{Interpretation:} ``If a future study differs at the individual level---not
just in population composition but also in unmeasured factors that determine
treatment effects---how well does the surrogate transport?''

\textbf{Key difference from X-level:} Observation-level treats each observation
as unique and reweights them individually. This includes both signal (treatment
effect heterogeneity captured by $X$) and noise (within-$X$ variation from $U$
and $\epsilon_i$). This makes observation-level more robust but also more
conservative, as it conflates signal with noise.

\subsubsection{Which Geometry to Use?}

\textbf{We recommend reporting both} for complementary evidence:

\begin{itemize}
    \item \textbf{X-level is optimistic:} Assumes mechanisms transport, gives
          upper bound on transportability under compositional shifts
    \item \textbf{Observation-level is conservative:} Includes unmeasured
          heterogeneity and noise, gives lower bound that's robust to model
          misspecification
    \item \textbf{Gap is informative:} Large gap $\rightarrow$ unmeasured
          heterogeneity matters; small gap $\rightarrow$ $X$ captures most
          relevant heterogeneity
\end{itemize}

\begin{table}[htbp]
\centering
\caption{Comparison of X-level vs Observation-level geometries}
\begin{tabular}{lll}
\toprule
Property & X-Level & Observation-Level \\
\midrule
What varies & $P(X)$ & $P(O)$ (everything) \\
Assumptions & Functions transport & None (beyond data) \\
Correlation & Higher (optimistic) & Lower (conservative) \\
Interpretation & Compositional shifts & General shifts \\
Best for & Well-chosen $X$ & Uncertain $X$ or unmeasured $U$ \\
\bottomrule
\end{tabular}
\end{table}

In practice:
\begin{itemize}
    \item If $X$ is well-chosen (captures key effect modifiers like age, severity,
          biomarkers), start with X-level
    \item Use observation-level as robustness check
    \item If results are similar, strong evidence of transportability
    \item If results diverge, unmeasured heterogeneity is important; interpret
          cautiously
\end{itemize}
```

---

## Priority 3: Polish

### Task 3.1: Update NEWS.md

**File:** `NEWS.md`

**Add Entry:**
```markdown
# surrogateTransportability 0.2.0 (Development)

## Major Changes

### Clarification of Core vs Experimental Functionality

Following peer review of the authoritative presentation, we have clarified which
functions represent the **core methodology** vs **experimental alternatives**:

**Core Methodology (use these for standard analysis):**
- `functional_correlation()`: Primary functional for surrogate evaluation
- `wasserstein_minimax_IF_inference()`: Main inference function
- X-level and Observation-level geometries (report both)
- TV and Wasserstein distance metrics

**Experimental Functions (use for specialized research):**
- `functional_concordance()`: Marked experimental (enables closed-form solutions)
- `functional_ppv()`, `functional_npv()`: Marked experimental (decision theory)
- `functional_conditional_mean()`: Marked experimental (non-differentiable)

**Alternative Paradigms:**
- `functional_cate_covariance()`: Marked as alternative (within-study, not across-study)
- `posterior_inference()`: Marked as alternative (Bayesian, not frequentist delta method)

### Documentation Improvements

- Added `@note` fields to all experimental functions clarifying status
- Updated README.md to emphasize core workflow
- Updated primary vignette to match authoritative presentation
- Added "Alternative Functions" section to documentation

### Breaking Changes

None. All functions remain available; only documentation changes.

## See Also

- `DEPRECATIONS.md`: Comprehensive roadmap for alignment with authoritative presentation
- `SLIDES_VS_PAPER_VS_PACKAGE.md`: Detailed comparison of components across materials

---

# surrogateTransportability 0.1.0

Initial release.
```

---

### Task 3.2: Add Lifecycle Badges

**Install lifecycle package:**
```r
# In DESCRIPTION, add:
Imports:
    lifecycle
```

**In Experimental Functions:**
```r
#' @importFrom lifecycle badge
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' [Rest of documentation]
```

**In Core Functions:**
```r
#' @description
#' `r lifecycle::badge("stable")`
#'
#' [Rest of documentation]
```

---

## Verification

### After Each Task

```r
# 1. Document changes
devtools::document()

# 2. Check package
devtools::check()

# 3. Test specific function
?functional_concordance  # Should show experimental note

# 4. Run examples
devtools::run_examples()
```

### Final Verification

```r
# 1. Full check
devtools::check()

# 2. Build vignettes
devtools::build_vignettes()

# 3. Build site (if using pkgdown)
pkgdown::build_site()

# 4. Test README
rmarkdown::render("README.Rmd")
```

---

## Common Issues and Solutions

### Issue 1: Roxygen2 Not Updating Help Files

**Solution:**
```r
# Force clean rebuild
unlink("man", recursive = TRUE)
devtools::document()
```

### Issue 2: Vignette Not Building

**Solution:**
```r
# Check vignette YAML
# Must have:
# output: rmarkdown::html_vignette
# vignette: >
#   %\VignetteIndexEntry{Title}
#   %\VignetteEngine{knitr::rmarkdown}
#   %\VignetteEncoding{UTF-8}
```

### Issue 3: Lifecycle Badges Not Showing

**Solution:**
```r
# Add to DESCRIPTION:
RdMacros: lifecycle

# Add to any file in R/:
#' @importFrom lifecycle deprecated
```

---

## Progress Tracking

### Priority 1 Checklist
- [ ] Task 1.1: Flag concordance functional
- [ ] Task 1.2: Flag PPV functional
- [ ] Task 1.3: Flag NPV functional
- [ ] Task 1.4: Flag conditional mean functional
- [ ] Task 1.5: Flag CATE covariance functional
- [ ] Task 1.6: Flag posterior inference
- [ ] Task 1.7: Update README.md
- [ ] Task 1.8: Update primary vignette
- [ ] Verify: Run devtools::check()

### Priority 2 Checklist
- [ ] Task 2.1: Add PTE misleading example to paper
- [ ] Task 2.2: Strengthen X-level vs Obs-level framing
- [ ] Generate figure for PTE example
- [ ] Update table of geometries
- [ ] Verify: Compile paper successfully

### Priority 3 Checklist
- [ ] Task 3.1: Update NEWS.md
- [ ] Task 3.2: Add lifecycle badges
- [ ] Build pkgdown site
- [ ] Final verification checks
- [ ] Update DEPRECATIONS.md status

---

## Timeline Estimate

- **Priority 1:** 4-6 hours (documentation updates)
- **Priority 2:** 8-10 hours (paper revisions + figure generation)
- **Priority 3:** 2-3 hours (polish)

**Total:** 14-19 hours of focused work

---

**Last Updated:** 2026-05-01
**Next Review:** After Priority 1 completion
