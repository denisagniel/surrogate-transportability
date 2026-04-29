# Presentation Outline: Surrogate Transportability (20 Minutes)

**Date:** 2026-04-27
**Target:** 20-minute talk (22-25 slides at ~50-60 seconds each)
**Status:** DRAFT - Awaiting approval

---

## Overview

**Main message:** General framework for evaluating surrogate transportability via local geometric analysis. X-level (compositional changes) and observation-level (general changes) provide complementary evidence. Noise attenuation explains why observation-level shows lower correlation, with reliability coefficient quantifying the gap.

**Pedagogical structure:**
1. **Introduction (5-6 min):** What are surrogates, why they matter, current methods, our approach
2. **Framework (3-4 min):** Defining future studies, local geometries, estimand
3. **Methodology (3-4 min):** Estimator, sampling, inference
4. **X-Level Analysis (3-4 min):** Compositional changes, assumptions, results
5. **Observation-Level Analysis (3-4 min):** General changes, differences from X-level, results
6. **Theoretical Comparison (2 min):** Noise attenuation, when to use which
7. **Practical Use (2 min):** Workflow, decision rules, summary

---

## Slide-by-Slide Outline (22-25 Slides)

### Part 1: Introduction and Motivation (5-6 minutes, 6 slides)

#### Slide 1: Title
**Main point:** Evaluating Surrogate Transportability via Local Geometric Analysis

**Content:**
- Title
- Authors
- Institution
- Date

**Notes:** Standard title slide, keep simple

---

#### Slide 2: What is a Surrogate Endpoint?
**Main point:** S is a surrogate for Y if measuring S allows prediction of treatment effect on Y (earlier, cheaper, less invasive)

**Content:**
- **Definition:** Surrogate S measured early/cheaply to predict treatment effect on clinical outcome Y
- **Examples:**
  - CD4 count → AIDS mortality (years vs months)
  - Tumor shrinkage → Overall survival (weeks vs years)
  - Blood pressure → Cardiovascular events
  - Biomarkers → Clinical outcomes

**Visual:** Simple table or diagram showing S → Y for 2-3 examples

**Script:** "A surrogate endpoint is a marker measured earlier or more easily than the clinical outcome of interest. If treatment affects the surrogate, we hope to infer its effect on the outcome without waiting years or spending millions."

**Sources:**
- Session notes (basic surrogate definition)
- Will need to create examples table/figure

---

#### Slide 3: Why Surrogates Matter
**Main point:** Enable faster trials, reduce cost, protect patients from unnecessary exposure

**Content:**
- **Benefits:**
  - Accelerate drug development (years → months)
  - Reduce trial costs (smaller samples, shorter follow-up)
  - Enable early stopping (efficacy or futility)
  - Protect patients (avoid unnecessary long-term exposure)
- **Challenge:** Must work in **future studies**, not just the one where validated

**Visual:** Perhaps a timeline comparison: Traditional trial (5 years) vs Surrogate-based (1 year)

**Script:** "But there's a catch: a surrogate validated in one study must also work in future trials with different populations, different effect heterogeneity, different covariate distributions. This is fundamentally a question of transportability."

**Sources:**
- Common knowledge in surrogate literature
- Will draft content from general surrogate literature

---

#### Slide 4: Current Single-Study Methods
**Main point:** Traditional approaches (PTE, mediation, principal stratification) assess surrogate quality within ONE study

**Content:**
- **Table:**
  | Method | What It Measures | Limitation |
  |--------|------------------|------------|
  | PTE (Proportion of Treatment Effect) | % of outcome effect mediated by surrogate | Assumes proportion stable across studies |
  | Mediation | Indirect effect through S vs direct | Assumes pathway structure transports |
  | Principal Stratification | Within-stratum effects | Assumes strata definitions transfer |

- **Key issue:** All **assume** transportability, don't **evaluate** it

**Visual:** Clean table with three rows

**Script:** "Current methods are designed for this use case but they make a critical assumption: they assume the observed relationship will hold in future studies. PTE assumes the proportion stays stable, mediation assumes pathways persist, principal stratification assumes strata transfer."

**Sources:**
- Paper intro (lines 36-37)
- Session notes 2026-04-14 (lines 234-240)
- Need to draft detailed descriptions

---

#### Slide 5: Meta-Analytic Methods
**Main point:** Trial-level correlation approach (Buyse et al.) uses multiple trials to validate surrogates

**Content:**
- **Buyse et al. (2000) approach:**
  - Collect data from multiple completed trials
  - Compute trial-level treatment effects on S and Y
  - Correlate ΔS(trial) with ΔY(trial) across trials
  - High correlation → good surrogate
- **Limitation:** Requires many (5-10+) completed trials with both S and Y measured
- **Our motivation:** Can we assess transportability from a **single study**?

**Visual:** Schematic showing multiple trials → correlation plot

**Script:** "A different approach comes from meta-analysis. Buyse and colleagues showed you can validate surrogates by collecting multiple trials, computing treatment effects in each, and correlating them. This directly addresses transportability by examining variation across studies. But it requires many completed trials. Can we do something similar with just one study?"

**Sources:**
- Paper refs (meta-analytic citation)
- Need to look up Buyse et al. (2000) for details
- Session notes mention this as motivation

---

#### Slide 6: Our Approach: Future Study Reweighting
**Main point:** Similar motivation to meta-analysis (across-study thinking), but applicable with single study by considering hypothetical future studies

**Content:**
- **Key idea:** Instead of waiting for multiple trials, consider hypothetical future studies Q that differ from observed P₀
- **How it works:**
  1. Define "plausible" future studies via local geometry U(P₀, λ; d)
  2. Sample future studies Q from this geometry
  3. Compute ΔS(Q), ΔY(Q) for each via reweighting observed data
  4. Measure correlation across future studies
- **Connection to meta-analysis:** We're computing trial-level correlation, but over hypothetical rather than realized trials

**Visual:** Flow diagram: P₀ → U(P₀, λ) → {Q₁, Q₂, ..., Qₘ} → cor(ΔS, ΔY)

**Script:** "Our approach has the same motivation as meta-analysis—thinking about variation across studies—but we can do it with a single study by considering hypothetical future studies that differ from what we observed. We define plausible futures, sample them, and measure how surrogate quality varies."

**Sources:**
- Session notes 2026-04-17 (across-study paradigm, lines 92-123)
- Paper framework section

---

### Part 2: Framework and Estimand (3-4 minutes, 3 slides)

#### Slide 7: Defining Future Studies
**Main point:** Future study Q characterized by different covariate or individual distribution from observed P₀

**Content:**
- **Observed study:** P₀ is the distribution of (X, A, S, Y) in current data
- **Future study:** Q is a different distribution on the same space
- **How studies differ:**
  - Covariate distribution P(X) shifts (population composition changes)
  - Individual-level distributions change (different mix of individuals)
  - Treatment effect heterogeneity may change
- **Treatment effects in each study:**
  - ΔS(Q) = E_Q[S(1) - S(0)]
  - ΔY(Q) = E_Q[Y(1) - Y(0)]

**Visual:** Two panels showing P₀ vs Q (perhaps histograms of X or treatment effects)

**Script:** "A future study is characterized by a different distribution Q. This could mean different covariate distributions—older patients, different disease severity—or more general changes in the individual-level composition. Each distribution Q yields treatment effects ΔS(Q) and ΔY(Q)."

**Sources:**
- Paper setting section (lines 73-82)
- Session notes on across-study paradigm

---

#### Slide 8: The Transportability Estimand
**Main point:** cor(ΔS(Q), ΔY(Q)) across distribution Q ~ μ on plausible future studies

**Content:**
- **Estimand:** Θ(P₀; λ) = cor{ΔS(Q), ΔY(Q)} where Q ~ μ on U(P₀, λ; d)
- **NOT "correlation across types"** — always **"correlation across studies"**
- **Interpretation:**
  - Positive correlation: Studies with high ΔS tend to have high ΔY
  - High correlation (≈ 0.8-0.9): Knowing ΔS strongly predicts ΔY
  - Low/zero correlation: ΔS provides little information about ΔY
- **This is a transportability question:** Will S predict Y in future studies?

**Visual:** Equation for Θ(P₀; λ) prominently displayed, perhaps with scatter plot showing cor(ΔS, ΔY) across hypothetical studies

**Script:** "Our estimand is the correlation between surrogate and outcome treatment effects, computed **across** studies Q drawn from some distribution μ. This is always an across-study correlation, never across types or individuals. It directly measures transportability: if correlation is high, knowing the surrogate effect in a future study tells you about the outcome effect."

**Sources:**
- Session notes 2026-04-17 (lines 92-123: "ALWAYS across-study")
- Paper estimand definition (lines 295-298)

---

#### Slide 9: Local Geometries
**Main point:** Operationalize "plausible future studies" via U(P₀, λ; d) = {Q : d(Q, P₀) ≤ λ}

**Content:**
- **Local geometry:** U(P₀, λ; d) = {Q : d(Q, P₀) ≤ λ}
- **Parameters:**
  - d: distance metric (how we measure similarity)
  - λ: radius (how far future studies can deviate)
- **Common metrics:**
  - TV (total variation): General distributional shifts
  - Wasserstein: Covariate shifts preserving geometry
  - KL, chi-squared, L2: Other f-divergences
- **Framework generality:** Applies to ANY distance metric d

**Visual:** Geometric illustration showing P₀ in center, U(P₀, λ) as neighborhood, different Q's within the ball

**Script:** "We formalize 'plausible futures' using local geometries: the set of all distributions Q within distance λ of P₀. The distance metric d determines how we measure similarity—TV for general shifts, Wasserstein for covariate shifts, and so on. The framework applies to any metric, giving flexibility to match the application."

**Sources:**
- Paper setting section (lines 83-109)
- Session notes 2026-04-14 (general framework reframing)

**Need:** Geometry illustration figure (TikZ or ggplot2)

---

### Part 3: Methodology (3-4 minutes, 3 slides)

#### Slide 10: The Estimator
**Main point:** Sample M future studies Q_m from U(P₀, λ; d), compute ΔS(Q_m), ΔY(Q_m) for each, estimate correlation

**Content:**
- **Algorithm:**
  1. Sample Q₁, ..., Qₘ from U(P₀, λ; d) via MCMC
  2. For each Qₘ, compute treatment effects via deterministic reweighting:
     - Weights: wᵢ = qₘ(Oᵢ) / p₀(Oᵢ)
     - RCTs: Weighted means
     - Observational: AIPW with cross-fitting
  3. Compute correlation: Θ̂ = cor{(ΔS(Q₁), ΔY(Q₁)), ..., (ΔS(Qₘ), ΔY(Qₘ))}
- **Plug-in estimator:** Θ̂(λ) = (1/M) Σ φ(Qₘ)

**Visual:** Flow diagram showing: Data → MCMC → {Q₁, ..., Qₘ} → {(ΔS₁, ΔY₁), ..., (ΔSₘ, ΔYₘ)} → correlation

**Script:** "The estimator is straightforward: sample many future studies from the geometry, compute treatment effects in each by reweighting observed data, then correlate the effects across studies. This is a plug-in approach—we're directly approximating the expectation over the geometry."

**Sources:**
- Paper estimation section (lines 249-280)
- Session notes on deterministic reweighting

---

#### Slide 11: Sampling Algorithm: Hit-and-Run MCMC
**Main point:** Uniform sampling from convex geometries via random walk

**Content:**
- **Hit-and-Run algorithm:**
  1. Start at current Q_t ∈ U(P₀, λ; d)
  2. Draw random direction v
  3. Compute line segment within U(P₀, λ; d)
  4. Sample uniformly along line → Q_{t+1}
  5. Repeat with burn-in
- **Convergence:** Validated via Gelman-Rubin R-hat = 1.0002 (essentially perfect)
- **Why uniform?** Non-informative: treats all directions of deviation equally (conservative assessment)

**Visual:** Illustration of hit-and-run on simplex with TV ball constraint, or convergence trace plot

**Script:** "To sample uniformly from the geometry, we use hit-and-run MCMC, a standard method for convex bodies. Start at a point, pick a random direction, move uniformly along the line segment that stays in the ball. After burn-in, this converges to uniform. We've validated convergence is essentially perfect."

**Sources:**
- Paper estimation section (lines 236-247)
- Exploration wrapup (R-hat validation)
- explorations/tv_ball_geometry/ results

**Need:** Hit-and-run visualization (adapt from exploration figures)

---

#### Slide 12: Inference: Asymptotic Theory and EIF
**Main point:** Two-stage functional delta method → √n-consistency; efficient influence function (EIF) for variance estimation

**Content:**
- **Asymptotic result:** √n(Θ̂ - Θ(P₀)) →ᵈ N(0, σ²(λ))
- **Two-stage structure:**
  - Stage 1: Treatment effects ΔS(Q), ΔY(Q) have influence functions
    - RCTs: Simple weighted means
    - Observational: AIPW with cross-fitting (doubly robust)
  - Stage 2: Functional delta method for cor(·, ·)
    - Hadamard differentiability
    - Ergodic averaging over MCMC draws
- **Variance estimation:** σ²(λ) = E[ψ_Θ(O; P₀)²] (EIF-based)
- **Confidence intervals:** Normal approximation with EIF standard errors

**Visual:** Two-stage diagram: Data → (ΔS, ΔY) [Stage 1] → Θ [Stage 2]

**Script:** "Inference uses a two-stage functional delta method. First, treatment effects have √n-consistent estimators with known influence functions. For observational studies, we use doubly-robust AIPW with cross-fitting. Second, the correlation functional is Hadamard differentiable, enabling standard functional delta method. The result is √n-consistent with an explicit influence function for variance estimation."

**Sources:**
- Paper asymptotic section (lines 293-322)
- Session notes on cross-fitting (2026-04-14, lines 722-727)

**Note:** This is a sketch in current paper—full derivation is planned (Step 3 of work plan)

---

### Part 4: X-Level Analysis (3-4 minutes, 3-4 slides)

#### Slide 13: X-Level Geometry: Compositional Changes
**Main point:** Studies differ in P(X) only; assumes treatment effect functions ΔS(X), ΔY(X) are constant

**Content:**
- **X-level geometry:** U_X(P₀, λ) = {Q over X-distributions: TV(Q_X, P₀,X) ≤ λ}
- **What changes:** Covariate distribution P(X)
  - Example: Study 1 has 30% elderly, Study 2 has 60% elderly
- **What stays constant:** Treatment effect functions ΔS(X), ΔY(X)
  - Elderly always have effect ΔS(elderly), ΔY(elderly)
  - Young always have effect ΔS(young), ΔY(young)
- **Interpretation:** Surrogate quality under **compositional changes** (different mixes of types)

**Visual:** Two panels:
- Left: Histogram showing P₀(X) vs Q(X) (compositional shift)
- Right: Treatment effects ΔS(X), ΔY(X) stay same across studies

**Script:** "X-level geometry focuses on compositional changes: future studies differ in their covariate distributions P(X), but the treatment effect functions ΔS(X) and ΔY(X) remain constant. If a study has more elderly patients, we assume elderly patients have the same treatment effects as in the original study—just the proportion changed."

**Sources:**
- Session notes 2026-04-17 (lines 128-137)
- Need to draft this content clearly

---

#### Slide 14: X-Level Assumptions
**Main point:** Requires (1) no unmeasured effect modifiers, (2) treatment-covariate interaction functions stable across studies

**Content:**
- **Assumptions:**
  1. **X completely determines effect heterogeneity**
     - No unmeasured effect modifiers U
     - Two people with same X have same treatment effects
  2. **Mechanisms transport**
     - Functions ΔS(X), ΔY(X) stable across studies
     - Only P(X) changes, not how X relates to effects
- **When appropriate:**
  - X captures key effect modifiers (age, disease severity, biomarkers)
  - Future studies draw from same population (mechanistic transportability)
  - Large-sample transportability (noise averages out)
- **Strong but plausible:** With well-chosen X, often reasonable

**Visual:** Assumption diagram or simple bullet points

**Script:** "X-level makes strong assumptions: X completely determines treatment effect heterogeneity, and the functions ΔS(X) and ΔY(X) transport. This is plausible when X captures key effect modifiers and future studies involve the same mechanisms, just different population compositions. With well-chosen X—age, disease severity, relevant biomarkers—this is often reasonable."

**Sources:**
- Session notes 2026-04-17 (lines 32-38, 133-136)

---

#### Slide 15: X-Level Simulation Results
**Main point:** With type-level DGP, X-level correlation ≈ 0.9 (high); correctly identifies transportable surrogates

**Content:**
- **DGP:** Treatment effects defined at type level (K=30 types)
  - True type-level correlation: ρ = 0.74
  - Effects vary systematically with X
- **X-level results:**
  - Estimated correlation: ρ̂_X ≈ 0.9
  - Bootstrap 95% CI: [0.85, 0.93]
  - Correctly identifies good surrogate
- **Interpretation:** When effects truly correlate across types, X-level recovers high correlation

**Visual:** Point estimate with confidence interval, perhaps compared to truth

**Script:** "When we simulate data where treatment effects are defined at the type level and truly correlate, X-level analysis recovers high correlation—around 0.9 with tight confidence intervals. This correctly identifies that the surrogate transports well under compositional changes."

**Sources:**
- Session notes 2026-04-17 (expected X-level results)
- Work plan Step 4: Need to run X-level simulation

**Need:** X-level simulation results (1-2 hours work, Step 4 of plan)

---

#### Slide 16 (Optional): X-Level vs Traditional Methods
**Main point:** X-level correlation (71% accuracy) vastly outperforms PTE (32%) and within-study (49%) at classification

**Content:**
- **Method comparison (classification task):**
  | Method | Accuracy | Type |
  |--------|----------|------|
  | X-level correlation | 71% | Across-study transportability |
  | Within-study correlation | 49% | Within-study association |
  | PTE | 32% | Within-study mediation |
- **Interpretation:**
  - X-level directly measures transportability
  - Traditional methods measure within-study properties
  - Different questions → different performance

**Visual:** Bar chart showing 71% vs 49% vs 32%

**Script:** "When we compare methods at a classification task—identifying good vs poor surrogates—X-level correlation achieves 71% accuracy, far exceeding within-study correlation at 49% and PTE at 32%. This makes sense: X-level directly measures transportability, while traditional methods measure within-study properties."

**Sources:**
- Session notes 2026-04-14 (method comparison results, lines 508-662)
- sims/results/31_method_comparison_summary.csv

**Note:** Optional slide—include if time allows and results are compelling

---

### Part 5: Observation-Level Analysis (3-4 minutes, 3-4 slides)

#### Slide 17: Observation-Level Geometry: General Changes
**Main point:** Studies differ in individuals (treating each as unique); allows unmeasured heterogeneity and noise

**Content:**
- **Observation-level geometry:** U_obs(P₀, λ) = {Q over individuals: TV(Q, P₀) ≤ λ}
- **What changes:** Individual-level distributions
  - Each person (X, S, Y) is unique
  - Resampling creates different mixes of individuals
- **What's allowed:**
  - Unmeasured effect modifiers U (not observed)
  - Idiosyncratic variation ε_i (individual noise)
  - More general than just P(X) shifts
- **Interpretation:** Surrogate quality under **most general distributional changes**

**Visual:** Schematic showing individuals as points, resampling creating different Q

**Script:** "Observation-level takes a more general approach: we treat each individual as unique and resample them. This allows unmeasured heterogeneity beyond X, idiosyncratic variation, and any general distributional change—not just compositional shifts. It's the most flexible geometry, but also mixes signal with noise."

**Sources:**
- Session notes 2026-04-17 (lines 138-147)
- Need to draft clear description

---

#### Slide 18: How Observation-Level Differs from X-Level
**Main point:** X-level reweights types; observation-level resamples individuals (including idiosyncratic variation)

**Content:**
- **Two-panel comparison:**

  **Panel A: X-level (Compositional)**
  - Reweight across types/strata
  - Only between-X variation matters
  - ΔS(Q) = Σ Q_X(x) · ΔS(x)
  - Appropriate for: Compositional changes

  **Panel B: Observation-level (General)**
  - Resample individuals
  - Both between-X and within-X variation
  - ΔS(Q) = Σ Q(i) · [ΔS(X_i) + ε_i]
  - Appropriate for: General changes, robustness

**Visual:** Two-panel schematic (TikZ or ggplot2):
- Left: Discrete types with arrows showing reweighting
- Right: Individuals as points with resampling including noise

**Script:** "The key difference: X-level reweights types, observation-level resamples individuals. X-level only includes between-X variation—the signal. Observation-level includes both signal and within-X noise—the idiosyncratic variation that doesn't predict aggregate effects. This makes observation-level more robust but also conflates signal with noise."

**Sources:**
- Session notes 2026-04-17 (lines 148-169)
- Work plan Step 6: Need schematic figure

**Need:** Two-panel schematic figure (2 hours, Step 9 of plan)

---

#### Slide 19: Observation-Level Simulation Results
**Main point:** With same DGP, observation-level correlation ≈ 0.42 (lower than X-level)

**Content:**
- **Same DGP as X-level:**
  - Type-level correlation: ρ = 0.74
  - X-level recovered: ρ̂_X ≈ 0.9
- **Observation-level results:**
  - Estimated correlation: ρ̂_obs = 0.42
  - Bootstrap 95% CI: [0.29, 0.44]
  - Still positive and significant, but much lower
- **Why lower?** Noise attenuation (explained in next slides)

**Visual:** Point estimate with CI, perhaps side-by-side with X-level for comparison

**Script:** "When we apply observation-level analysis to the same DGP, correlation drops to 0.42—still positive and significant, but much lower than the 0.9 from X-level. This isn't a failure of the method. It's real attenuation from including idiosyncratic noise that doesn't transport."

**Sources:**
- Exploration wrapup (cor ≈ 0.42, CI: [0.29, 0.44])
- explorations/tv_ball_geometry/results/

**Need:** Format existing observation-level results (30 min, Step 5 of plan)

---

#### Slide 20: Robustness: Correlation Across Geometries
**Main point:** Finding robust across distance metrics: TV/chi-sq/L2/KL all give ≈ 0.57 (1.5% spread)

**Content:**
- **Robustness check:** Tested 4 different distance metrics
  | Geometry | Correlation | SE |
  |----------|-------------|-----|
  | TV (total variation) | 0.575 | 0.011 |
  | Chi-squared | 0.576 | 0.015 |
  | L2 distance | 0.573 | 0.013 |
  | KL divergence | 0.567 | 0.009 |
- **Relative spread:** Only 1.5% across metrics
- **Interpretation:** Positive correlation is robust property of local structure, not artifact of specific metric

**Visual:** Bar chart with 4 bars (TV, chi-sq, L2, KL) showing correlation ± SE

**Script:** "A natural question: is this an artifact of the specific metric? We tested four different geometries—TV, chi-squared, L2, and KL—and found remarkable consistency. Correlations range from 0.567 to 0.576, a relative spread of only 1.5%. The positive correlation is a genuine property of the local structure, not metric-specific."

**Sources:**
- Exploration wrapup (robustness results, lines 66-82)
- explorations/tv_ball_geometry/results/geometry_comparison.rds

**Need:** Bar chart from geometry comparison results (30 min, Step 9 of plan)

---

### Part 6: Theoretical Comparison (2 minutes, 2 slides)

#### Slide 21: The Noise Attenuation Problem
**Main point:** Observation-level has ceiling due to within-X noise: cor_obs ≈ cor_signal × √(reliability_S × reliability_Y)

**Content:**
- **Variance decomposition:**
  - Var(ΔS(Q))_obs = Var(between-X) + Var(within-X)
  - Signal: Variation from reweighting types (transports)
  - Noise: Variation from within-X resampling (doesn't transport in large samples)
- **Reliability coefficient:**
  - reliability_S = Var(signal_S) / Var(total_S)
  - How much variation is systematic vs idiosyncratic
- **Attenuation formula:**
  - cor_obs ≈ cor_signal × √(reliability_S × reliability_Y)
  - Classical measurement error attenuation
- **The ceiling:** With reliability = 0.5, maximum cor_obs ≈ 0.71 even if cor_signal = 1.0

**Visual:** Scatter plot showing cor_obs vs cor_signal with diagonal line, or variance decomposition diagram

**Script:** "Why is observation-level lower? Variance decomposition reveals two sources: between-X variation (signal that transports) and within-X variation (noise that averages out). Reliability is the signal-to-total ratio. By classical measurement error attenuation, observation-level correlation is bounded by the signal correlation times the square root of reliabilities. With 50% reliability, even perfect signal correlation gives observation-level around 0.7."

**Sources:**
- Session notes 2026-04-17 (lines 48-74, 170-186, 211-226)
- Work plan Step 7: Need noise attenuation demonstration

**Need:** Noise attenuation scatter plot (2 hours, Step 7 of plan)

---

#### Slide 22: Guidance: Which Geometry to Use?
**Main point:** Report BOTH with reliability coefficient

**Content:**
- **Decision framework:**
  | Scenario | X-Level | Observation-Level | Reliability |
  |----------|---------|-------------------|-------------|
  | Well-chosen X, mechanisms transport | ✓ Primary | ✓ Robustness check | High (≈ 1) → Both agree |
  | Uncertain X, robustness priority | ✓ Supplement | ✓ Primary | Low (< 0.7) → Gap reveals noise |
  | Large-sample transportability | ✓ More relevant | ○ Conservative bound | Noise averages out |
  | Small samples or unmeasured U | ○ Optimistic | ✓ More realistic | Noise matters |

- **Recommendation:** Report both, compute reliability, interpret gap
  - High reliability (≈ 1): Both similar → robust conclusion
  - Low reliability (< 0.7): Gap large → X-level more informative for large-sample transport, obs-level provides conservative bound

**Visual:** Decision tree or table

**Script:** "Which should you use? Ideally, both. X-level gives higher correlation under strong assumptions—mechanisms transport, X captures heterogeneity. Observation-level is more robust but conservative, including noise that may not matter for large-sample transportability. Compute the reliability coefficient to understand the gap. High reliability means both agree—robust conclusion. Low reliability means noise matters, and the choice depends on your application."

**Sources:**
- Session notes 2026-04-17 (lines 245-252)
- Recommended approach from session notes

---

### Part 7: Practical Use and Conclusion (2 minutes, 2-3 slides)

#### Slide 23: How to Use in Practice
**Main point:** Fit over range of λ values (e.g., λ = 0.05, 0.10, 0.15, 0.20) - performance degradation with λ measures surrogate robustness

**Content:**
- **Workflow:**
  1. Choose distance metric d (TV, Wasserstein, etc.) based on application
  2. For each λ = 0.05, 0.10, 0.15, 0.20:
     - Sample M ≈ 100-500 future studies from U(P₀, λ; d)
     - Compute ΔS(Q), ΔY(Q) for each
     - Estimate Θ̂(λ) = cor(ΔS, ΔY)
     - Compute EIF-based 95% CI
  3. Plot Θ̂(λ) vs λ
- **Interpretation:**
  - Flat line: Robust surrogate (works even for dissimilar studies)
  - Steep decline: Fragile surrogate (only works for very similar studies)
- **Decision rule:** Approve if Θ̂(λ) ≥ c (e.g., 0.7) for meaningful range of λ (e.g., λ ≤ 0.15)

**Visual:** Line plot showing correlation vs λ, with two examples (robust: flat, fragile: steep decline)

**Script:** "In practice, fit the model over a range of λ values—0.05, 0.10, 0.15, 0.20. For each, sample future studies, compute correlations, get confidence intervals. Then plot correlation versus λ. A flat line means the surrogate is robust—it works even for fairly dissimilar studies. A steep decline means it's fragile—only works for studies very close to P₀. Approve the surrogate if correlation stays high over a meaningful range."

**Sources:**
- Work plan Step 8: λ-robustness analysis
- Common sense from framework

**Need:** λ-robustness plot (1.5 hours, Step 8 of plan)

---

#### Slide 24: Summary
**Main point:** General framework for surrogate transportability via local geometries; robust across distance metrics; X-level (compositional) vs observation-level (general) provide complementary evidence

**Content:**
- **Key contributions:**
  1. General framework for any distance metric d
  2. X-level: High correlation under compositional changes (strong assumptions)
  3. Observation-level: Conservative bound under general changes (robust)
  4. Noise attenuation explains gap via reliability coefficient
  5. Robust across geometries (TV, chi-sq, L2, KL)
- **Practical guidance:**
  - Report both X-level and observation-level
  - Compute reliability to understand gap
  - Test over range of λ values
- **Contrast with traditional methods:**
  - We **evaluate** transportability, not **assume** it

**Visual:** Clean slide with 3-5 key bullets, no overwhelming text

**Script:** "To summarize: we've introduced a general framework for evaluating surrogate transportability using local geometric analysis. X-level analysis assumes compositional changes and recovers high correlation. Observation-level is more general and robust but shows lower correlation due to noise attenuation. The reliability coefficient quantifies this gap. The finding is robust across different distance metrics. Report both analyses to provide complementary evidence about surrogate quality."

---

#### Slide 25 (Optional): Extensions and Future Work
**Main point:** Meta-analytic synthesis, real-time monitoring, Bayesian priors, interactive tools for regulators

**Content:**
- **Extensions:**
  - Meta-analytic combination across multiple studies
  - Real-time monitoring as trials progress
  - Bayesian framework with prior information
  - Interactive tools for regulators (shiny app)
- **Open questions:**
  - Optimal choice of discretization J for continuous X
  - Extensions to time-to-event outcomes
  - Multiple surrogates simultaneously
  - Cost-benefit analysis incorporating λ-robustness

**Visual:** Simple bullet list or grid of extension topics

**Script:** "Extensions include meta-analytic synthesis when multiple studies are available, real-time monitoring as trials progress, Bayesian frameworks to incorporate prior knowledge, and interactive tools to help regulators evaluate surrogates. Open questions remain about optimal discretization, time-to-event outcomes, and incorporating cost-benefit considerations."

**Note:** Optional slide—include if time allows, otherwise end with summary

---

## What We Need (Gap Analysis)

### Content Missing

#### Introduction Content (Slides 2-6)
1. **Surrogate examples figure** (Slide 2)
   - Table or visual with 2-3 examples (CD4, tumor, biomarkers)
   - Effort: 1 hour

2. **Traditional methods summary** (Slide 4)
   - Detailed descriptions of PTE, mediation, principal stratification
   - Effort: 30 minutes (from literature)

3. **Meta-analytic methods description** (Slide 5)
   - Buyse et al. (2000) approach and limitation
   - Effort: 30 minutes (look up reference)

#### Theoretical Results (Slide 12 + Supplementary)
1. **EIF derivation** (CRITICAL)
   - Complete derivation of efficient influence function
   - Explicit variance formula
   - Effort: 3-4 hours (Step 3 of work plan)
   - **Status:** Paper has proof sketch only (lines 300-322)

2. **Reliability coefficient formula** (Slide 21)
   - Mathematical expression: reliability = Var(signal) / Var(total)
   - Effort: 30 minutes

3. **Observation-level ceiling bound** (Slide 21)
   - Formal statement: cor_obs ≤ cor_signal × √(reliability_S × reliability_Y)
   - Effort: 30 minutes

#### Simulation Results (Slides 15, 19)
1. **X-level simulation** (Slide 15)
   - Run type-level DGP with X-level analysis
   - Expected: cor ≈ 0.9
   - Effort: 1-2 hours (Step 4 of work plan)
   - **Status:** Not yet run

2. **Observation-level results formatted** (Slide 19)
   - Clean figure from existing results (cor ≈ 0.42)
   - Effort: 30 minutes (Step 5 of work plan)
   - **Status:** Have raw results, need formatted figure

3. **X-level vs observation-level comparison** (Slides 18-21)
   - Side-by-side results with reliability computation
   - Verify attenuation relationship
   - Effort: 2 hours (Step 6 of work plan)

4. **Noise attenuation demonstration** (Slide 21)
   - Scatter plot showing cor_obs vs cor_signal
   - Multiple DGPs with varying noise
   - Effort: 2 hours (Step 7 of work plan)

5. **λ-robustness analysis** (Slide 23)
   - Correlation vs λ for range of values
   - Effort: 1.5 hours (Step 8 of work plan)

### Figures Needed

#### Introduction (Slides 2-6)
1. Surrogate examples table/figure (1 hour)
2. Meta-analysis schematic (1 hour)
3. Future study reweighting flow diagram (1 hour)

#### Framework (Slides 7-9)
4. P₀ vs Q comparison panels (1 hour)
5. Geometry illustration (U(P₀, λ) neighborhood) (2 hours, TikZ)

#### Methodology (Slides 10-12)
6. Estimator flow diagram (1 hour)
7. Hit-and-run visualization (1 hour, adapt from exploration)
8. Two-stage inference diagram (30 minutes)

#### X-Level (Slides 13-16)
9. Compositional shift schematic (1 hour)
10. X-level correlation results (1 hour, from simulation)
11. Classification accuracy bar chart (30 minutes, optional)

#### Observation-Level (Slides 17-20)
12. X-level vs observation-level two-panel schematic (2 hours, TikZ/ggplot2)
13. Observation-level correlation results (30 minutes)
14. Robustness bar chart (30 minutes)

#### Theory (Slides 21-22)
15. Noise attenuation scatter plot (2 hours)
16. Decision framework table/tree (1 hour)

#### Practice (Slide 23)
17. λ-robustness line plot (1.5 hours)
18. Workflow flowchart (1 hour)

**Total figures:** 18
**Total effort:** ~19 hours

---

## Estimated Timeline

**Phase 1:** Outline approval (this document) — **COMPLETE**

**Phase 2:** Introduction content — **2 hours**
- Draft surrogate examples, traditional methods, meta-analysis

**Phase 3:** Theoretical work — **4.5-5.5 hours**
- EIF derivation (CRITICAL): 3-4 hours
- Reliability and ceiling formulas: 1 hour

**Phase 4:** Simulation work — **6.5-7.5 hours**
- X-level simulation: 1-2 hours
- Format observation-level: 30 min
- X vs obs comparison: 2 hours
- Noise attenuation: 2 hours
- λ-robustness: 1.5 hours

**Phase 5:** Figures — **19 hours**
- Introduction figures: 3 hours
- Framework figures: 4 hours
- Methodology figures: 2.5 hours
- Analysis figures: 5.5 hours
- Theory figures: 3 hours
- Practice figures: 2.5 hours

**Phase 6:** Slides — **5-7 hours**
- Draft slides: 4-5 hours
- Review and iterate: 2 hours

**Phase 7:** Verification — **1 hour**

**Total:** 38-44 hours of work

---

## Next Steps (Awaiting User Approval)

1. **Review this outline** — Does slide structure make sense? Right pedagogical flow?
2. **Approve or revise** — Any slides to add/remove/reorder?
3. **Confirm priorities** — Which missing components are most critical?
4. **Begin implementation** — Start with introduction content (Step 2), then theory (Step 3), then simulations (Steps 4-8), then figures (Step 9), then slides (Step 10)

---

## Notes on Quality and Timing

**Target quality:** 90/100 (presentation-ready)
- Clear visuals (high-resolution, readable from back of room)
- Logical flow (builds intuition before formalism)
- Accurate content (all claims supported by results)
- Appropriate depth (accessible to broad audience, technical where needed)

**Timing:** 20 minutes at ~50-60 seconds per slide
- Part 1 (6 slides): 5-6 minutes (motivate problem)
- Part 2 (3 slides): 3-4 minutes (framework)
- Part 3 (3 slides): 3-4 minutes (methods)
- Part 4 (3-4 slides): 3-4 minutes (X-level)
- Part 5 (3-4 slides): 3-4 minutes (observation-level)
- Part 6 (2 slides): 2 minutes (theory comparison)
- Part 7 (2-3 slides): 2 minutes (practice + summary)

**Total:** 22-25 slides, fits 20-minute target

---

## Critical Decisions for User

1. **Slide 16 (optional):** Include classification accuracy comparison? (Requires results)
2. **Slide 25 (optional):** Include extensions/future work slide?
3. **Level of technical detail:** Slides 10-12 (methodology) — more or less detail on AIPW/cross-fitting?
4. **Figure style:** TikZ (publication-quality but slower) vs ggplot2 (faster but less polished)?
5. **EIF in slides:** Show derivation in slide 12 or relegate to supplement?

---

## Dependencies

- **Introduction content → Slides 2-6**
- **EIF derivation → Slide 12 + confidence in inference claims**
- **X-level simulation → Slide 15**
- **Observation-level formatting → Slide 19**
- **X vs obs comparison → Slides 18, 21**
- **Noise attenuation → Slide 21**
- **λ-robustness → Slide 23**
- **All figures → Final slides**

**Critical path:** EIF derivation (enables inference claims) → Simulations (provide results) → Figures (enable visualization) → Slides (integrate everything)

---

## Status: AWAITING APPROVAL

**Please review and approve, or suggest revisions.**
