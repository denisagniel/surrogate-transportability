# Presentation Outline: Surrogate Transportability (20 Minutes)

**Date:** 2026-04-27 (Updated: 2026-04-29)
**Target:** 20-minute talk (21-24 slides at ~50-60 seconds each)
**Status:** REVISED - Comparative advantage framing, general framework, two geometry approaches, simulation results removed pending validation

---

## Overview

**Main message:** General framework for evaluating surrogate transportability via local geometric analysis. X-level (compositional changes) and observation-level (general changes) provide complementary evidence. Noise attenuation explains why observation-level shows lower correlation, with reliability coefficient quantifying the gap.

**Pedagogical structure:**
1. **Introduction (7-8 min):** What are surrogates (across domains), why they matter, systematic review of existing methods (mediation/PTE, principal stratification, meta-analysis), comparative advantage summary, our approach
2. **Framework (3-4 min):** Distribution of future studies, general estimand (any functional), local geometries (one operationalization)
3. **Methodology (3-4 min):** Estimator, sampling, inference
4. **Two Approaches to Geometries (5-6 min):** Choosing geometry, X-level (compositional + assumptions + expectations), observation-level (general + expectations)
5. **Theoretical Comparison (2 min):** Noise attenuation, when to use which
6. **Practical Use (2 min):** Workflow, software, sample sizes, summary

**Key narrative arc:** Systematically show limitations of each existing approach → Our method addresses ALL limitations → General framework (distribution + functionals + operationalization) → Two geometry approaches with trade-offs → Evidence both work → Practical guidance

---

## Slide-by-Slide Outline (21-24 Slides)

### Part 1: Introduction and Motivation (7-8 minutes, 8 slides)

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
**Main point:** S is a surrogate for Y if measuring S allows prediction of treatment effect on Y (earlier, cheaper, more abundant)

**Content:**
- **General definition:** Surrogate S measured cheaply/abundantly to predict treatment/intervention effect on gold-standard outcome Y

- **Examples across domains:**

  | Domain | Surrogate (S) | Outcome (Y) | Why S is useful |
  |--------|---------------|-------------|-----------------|
  | Clinical trials | CD4 count | AIDS mortality | Months vs years |
  | Clinical trials | Tumor shrinkage | Overall survival | Weeks vs years |
  | PPI / ML | ML prediction from features | Gold-standard label | Small n_Y vs large n_S |
  | Observational | Administrative claims | Chart-reviewed outcome | Always available vs costly |
  | Observational | Sensor/wearable data | Clinical assessment | Continuous vs intermittent |

**Visual:** Table with 5 rows showing cross-domain applications

**Script:** "A surrogate is any measurement that's cheaper, faster, or more abundant than the gold-standard outcome. In clinical trials, that's CD4 count measured in months versus mortality in years. In machine learning and prediction-powered inference, it's an ML prediction from cheap features versus expensive gold-standard labels. In observational studies, it's administrative claims versus chart review, or wearable sensors versus clinical visits. The common thread: we want to use the abundant surrogate S to infer treatment effects on the rare outcome Y."

**Sources:**
- Clinical: Standard surrogate literature
- PPI: Angelopoulos et al. (2023)
- Observational: Healthcare data applications

---

#### Slide 3: Why Surrogates Matter (Beyond Clinical Trials)
**Main point:** Surrogate endpoints enable faster decisions across clinical trials, prediction-powered inference, and observational studies with limited gold-standard outcomes

**Content:**
- **Applications span multiple domains:**

  **Clinical Trials:**
  - Accelerate drug development (years → months)
  - Reduce costs (smaller samples, shorter follow-up)
  - Enable early stopping (efficacy or futility)

  **Prediction-Powered Inference (PPI) & ML Applications:**
  - Small gold-standard labeled dataset (Y) + large surrogate dataset (S)
  - ML model predicts Y from cheap features
  - Use surrogate to improve inference when gold-standard outcomes are expensive/rare

  **Observational Studies:**
  - Administrative data (S) abundant, chart review (Y) costly
  - Sensor data (S) continuous, clinical assessment (Y) intermittent
  - Self-report (S) cheap, biomarker (Y) expensive

- **Universal challenge:** Must work in **future studies/populations**, not just the one where validated

**Visual:** Three-panel figure showing clinical trial timeline, PPI workflow (small Y + large S), and observational data hierarchy

**Script:** "Surrogates matter far beyond clinical trials. In prediction-powered inference, we have small gold-standard datasets and large surrogate datasets—ML models predict expensive outcomes from cheap features. In observational studies, administrative data is abundant while chart review is costly. The common thread: we need to know if the surrogate relationship will hold in future studies with different populations, different covariate distributions, different effect heterogeneity. This is fundamentally a question of transportability."

**Sources:**
- Clinical trials: Standard surrogate literature
- PPI: Angelopoulos et al. (2023), "Prediction-Powered Inference"
- Observational: Healthcare applications (claims → outcomes)

---

#### Slide 4: Current Methods 1/3: Mediation & PTE
**Main point:** Standard single-study approaches identify functionals of the CURRENT study, not future studies

**Content:**
- **Mediation framework:**
  - Treatment A affects outcome Y through two pathways:
    - **Indirect effect:** A → S → Y (effect mediated by surrogate)
    - **Direct effect:** A → Y (not through surrogate)
  - **PTE (Proportion of Treatment Effect):** Indirect effect / Total effect
  - Good surrogate: High PTE (most of effect goes through S)

- **Key decomposition:**
  - Total effect = Indirect + Direct
  - PTE = Indirect / Total
  - If PTE ≈ 1, knowing ΔS tells you most of ΔY **in this study**

- **PTE vs Mediation:**
  - **Mediation:** Assumes S lies on causal pathway from A to Y
  - **PTE:** Can be computed even if S is not on pathway (just needs correlation structure)

- **CRITICAL LIMITATION: Current study estimand**
  - Measures how S and Y relate **in the observed study**
  - Assumes this relationship transports to future studies
  - **Evaluates association, assumes transportability**

**Visual:** Mediation DAG with three panels + limitation box:
- Panel A: Causal structure (A → S → Y with direct path A → Y)
- Panel B: Effect decomposition (Total = Indirect + Direct)
- Panel C: PTE formula (Indirect / Total)
- **Red box:** "Estimand: Functional of P₀ only. Assumes transportability to future studies."

**Script:** "The standard approach is mediation analysis. Treatment affects the outcome through an indirect path via the surrogate and a direct path. PTE—proportion of treatment effect—is the indirect divided by total. If PTE is high, most of the effect goes through S. Mediation assumes S is on the causal pathway; PTE just needs the correlation structure. But both share a critical limitation: they measure how S and Y relate in the current study and assume this relationship transports. They identify functionals of P₀, not functionals that quantify transportability across future studies."

**Sources:**
- VanderWeele (2015), *Explanation in Causal Inference*
- Freedman et al. (1992) on PTE
- Pearl (2001) on mediation formulas
- Need to create mediation DAG figure with limitation callout

---

#### Slide 5: Current Methods 2/3: Principal Stratification
**Main point:** Alternative single-study approach with TWO major limitations: current study estimand + requires binary/categorical S

**Content:**
- **Principal stratification framework (Frangakis & Rubin, 2002):**
  - Define strata based on potential surrogate values: S(0) and S(1)
  - For binary S: 4 strata (2×2 combinations)
    - "Always-high": S(0) = high, S(1) = high
    - "Responders": S(0) = low, S(1) = high
    - "Always-low": S(0) = low, S(1) = low
  - Examine treatment effect on Y **within** each stratum
  - Good surrogate: ΔY large in strata where S responds, small where S doesn't

- **Surrogate quality via principal effects (ASOCE):**
  - If treatment only affects Y in strata where it affects S → good surrogate
  - Association of surrogate and outcome causal effects

- **CRITICAL LIMITATIONS:**
  1. **Current study estimand:** Measures within-stratum effects **in P₀**, assumes they transport
  2. **Binary/categorical S only:** Continuous S → infinite strata → intractable
     - In practice: Must discretize (e.g., CD4 count → high/low)
     - Loses information, arbitrary cutpoints
     - Not applicable for naturally continuous surrogates

**Visual:** Diagram showing:
- Panel A: Four principal strata (2×2 table for binary S)
- Panel B: Treatment effects on Y within each stratum
- Panel C: Good surrogate pattern
- **Red box 1:** "Estimand: Functional of P₀ only"
- **Red box 2:** "Requires binary/categorical S. Continuous S intractable."

**Script:** "Principal stratification defines strata based on potential surrogate values—for binary S, four strata. The idea: if treatment only affects the outcome in strata where it affects the surrogate, that's a good surrogate. But this approach has two critical limitations. First, like mediation, it identifies functionals of the current study and assumes they transport. Second, it essentially requires binary or categorical surrogates. With continuous S, you have infinite strata, which is intractable. In practice, you must discretize—CD4 count becomes high versus low—losing information and imposing arbitrary cutpoints. This limits applicability severely."

**Sources:**
- Frangakis & Rubin (2002), "Principal Stratification in Causal Inference"
- Gilbert & Hudgens (2008) - HIV vaccine trials with binary markers
- Li et al. (2010) on ASOCE
- Wolfson & Gilbert (2010) - binary biomarker applications
- Need to create principal stratification diagram with dual limitation callouts

---

#### Slide 6: Current Methods 3/3: Meta-Analytic Approach
**Main point:** The GOLD STANDARD approach that addresses transportability directly, but requires multiple completed studies

**Content:**
- **Buyse et al. (2000) approach:**
  - Collect data from multiple completed studies (trials, cohorts, etc.)
  - Compute study-level treatment effects on S and Y
  - Correlate ΔS(study) with ΔY(study) **across studies**
  - High correlation → good surrogate

- **KEY ADVANTAGE: Future study estimand**
  - Directly measures variation **across studies**
  - Evaluates transportability, doesn't just assume it
  - If cor(ΔS, ΔY) high across realized studies → will likely hold in future studies

- **CRITICAL LIMITATION: Requires multiple studies**
  - Need 5-10+ completed studies with both S and Y measured
  - Often not available (new treatments, rare diseases, novel surrogates)
  - Must wait years for sufficient studies to accumulate

**Visual:** Schematic showing:
- Panel A: Multiple studies (Study 1, Study 2, ..., Study K)
- Panel B: Scatter plot of (ΔS(k), ΔY(k)) across studies
- Panel C: Correlation estimate
- **Green box:** "Estimand: cor(ΔS(Q), ΔY(Q)) across studies ✓"
- **Red box:** "Requires K ≥ 5-10 completed studies"

**Script:** "Meta-analysis offers a fundamentally different approach. Buyse and colleagues collect multiple studies, compute treatment effects in each, and correlate them across studies. This is the gold standard because it directly addresses transportability—it measures variation across realized studies, so if the correlation is high across past studies, it likely holds for future ones. But there's a major practical limitation: you need many completed studies—typically 5 to 10 or more—all measuring both S and Y. This data is often unavailable for new treatments, rare diseases, or novel surrogates. Can we get the advantages of meta-analysis from a single study?"

**Sources:**
- Buyse et al. (2000), "Validation of Surrogate Endpoints in Multiple Randomized Trials"
- Burzykowski et al. (2005) on trial-level surrogacy
- Paper intro (meta-analytic motivation)

---

#### Slide 7: Summary of Existing Methods: Trade-offs
**Main point:** Each existing method has critical limitations—no single approach addresses transportability without restrictions

**Content:**
- **Comparison table:**

| Method | Future Study Estimand? | Applicable to Continuous S? | Requires Multiple Studies? |
|--------|------------------------|----------------------------|----------------------------|
| **Mediation/PTE** | ✗ (Current study only) | ✓ Yes | ✗ No |
| **Principal Stratification** | ✗ (Current study only) | ✗ Binary/categorical only | ✗ No |
| **Meta-Analysis** | ✓ Yes (gold standard) | ✓ Yes | ✗ Yes (5-10+ studies) |

- **The dilemma:**
  - Single-study methods (mediation, PS): Don't address transportability directly
  - Meta-analysis: Addresses transportability but requires data often unavailable

- **What we want:**
  - ✓ Future study estimand (like meta-analysis)
  - ✓ Applicable to any surrogate type (like mediation)
  - ✓ Works with single study (like mediation/PS)

**Visual:** Table with checkmarks (✓) and X's (✗), highlighting the tension

**Script:** "Let's step back and compare these approaches. Mediation and PTE measure relationships in the current study, not across future studies. Principal stratification has that same limitation plus it only works for binary or categorical surrogates—continuous surrogates are intractable. Meta-analysis is the gold standard because it directly addresses transportability by examining variation across studies, but it requires many completed studies that are often unavailable. We face a dilemma: single-study methods don't address transportability directly, while meta-analysis requires data we often don't have. What we want is the best of both worlds: a future study estimand like meta-analysis, applicable to any surrogate type like mediation, but working with a single study. Can we achieve this?"

**Sources:**
- Synthesis from Slides 4-6
- Motivates the approach

---

#### Slide 8: Our Approach: Future Study Reweighting
**Main point:** Addresses ALL three limitations: future study estimand, any surrogate type, single study

**Content:**
- **Key idea:** Instead of waiting for multiple realized studies, consider hypothetical future studies Q that differ from observed P₀

- **How it works:**
  1. Define "plausible" future studies: a distribution of future studies
  2. Sample future studies Q₁, ..., Qₘ from this distribution
  3. Compute ΔS(Q), ΔY(Q) for future study
  4. Estimate any functional you want: one example: cor(ΔS, ΔY) **across** sampled future studies

- **Connection to meta-analysis:** Same estimand—study-level correlation—but over hypothetical rather than realized studies

- **Addresses all limitations:**
  - ✓ **Future study estimand:** cor(ΔS(Q), ΔY(Q)) across distributions Q (like meta-analysis)
  - ✓ **Any surrogate type:** Binary, continuous, count—framework is fully general
  - ✓ **Single study:** Reweight observed data to create hypothetical futures (like mediation/PS)

**Visual:** Two panels:
- Panel A: Flow diagram: P₀ → U(P₀, λ) → {Q₁, ..., Qₘ} → cor(ΔS, ΔY)
- Panel B: Comparison table showing checkmarks for all three desiderata

**Script:** "Our approach achieves all three desiderata simultaneously. The key idea: instead of waiting for multiple realized studies, we consider a distribution of hypothetical future studies. We sample from this distribution, compute treatment effects in each hypothetical study, and estimate functionals across studies—for example, the correlation between surrogate and outcome effects. This gives us a future study estimand like meta-analysis, works for any surrogate type like mediation, and requires only a single study. It's meta-analysis without waiting for the data."

**Sources:**
- Session notes 2026-04-17 (across-study paradigm)
- Paper framework section
- Motivated by comparison in Slide 7

---

### Part 2: Framework and Estimand (3-4 minutes, 3 slides)

#### Slide 9: A Distribution of Future Studies
**Main point:** Instead of one future study, consider a DISTRIBUTION over many possible future studies

**Content:**
- **Observed study:** P₀ is the distribution of (X, A, S, Y) in current data

- **Future studies:** Many possible distributions Q that differ from P₀
  - Different patient populations (age, severity, demographics)
  - We assume that the new study is different, but not *too different* from the current study

- **Each Q yields treatment effects:**
  - ΔS(Q) = E_Q[S(1) - S(0)]
  - ΔY(Q) = E_Q[Y(1) - Y(0)]

- **A distribution μ over future studies:**
  - Not just one Q, but many Q's drawn from distribution μ
  - μ represents our uncertainty about which future study will occur
  - Different choices of μ encode different assumptions about plausibility

**Visual:** Three panels:
- Panel A: Current study P₀
- Panel B: Several example future studies Q₁, Q₂, Q₃, ...
- Panel C: Distribution μ over the space of possible studies

**Script:** "Here's the key conceptual shift: instead of imagining one specific future study, we consider a distribution over many possible future studies. The current study is P₀. Future studies are different distributions Q—different populations, different settings, different time periods. Each Q yields treatment effects ΔS(Q) and ΔY(Q). We characterize our uncertainty with a distribution μ over possible future studies. This distribution μ encodes what we think is plausible."

**Sources:**
- Paper framework section
- Session notes on across-study paradigm

---

#### Slide 10: General Estimand: Any Functional Across Studies
**Main point:** Framework estimates E_μ[φ(Q)]—ANY functional φ of treatment effects across the distribution μ

**Content:**
- **General form:** Θ(μ) = E_μ[φ(Q)] where Q ~ μ
  - φ(Q): Any function of treatment effects ΔS(Q), ΔY(Q)
  - E_μ[·]: Expectation over the distribution of future studies

- **Examples of functionals φ:**
  - **Correlation:** φ(Q) = cor{ΔS(Q), ΔY(Q)} across studies (our focus today)
  - **Probability:** φ(Q) = P(sign(ΔS(Q)) = sign(ΔY(Q))) (concordance)
  - **Conditional mean:** φ(Q) = E[ΔY(Q) | ΔS(Q) ∈ range] (regression)
  - **Proportion:** φ(Q) = P(|ΔY(Q)| ≥ c | |ΔS(Q)| ≥ c) (effect size threshold)
  - Custom functionals for specific applications

- **Today's example: Correlation**
  - φ(Q) = cor{(ΔS(Qᵢ), ΔY(Qᵢ))} for Qᵢ ~ μ
  - Interpretation: Studies with high ΔS tend to have high ΔY
  - High correlation (≈ 0.8-0.9) → knowing ΔS predicts ΔY
  - **NOT "correlation across types"** — always **"correlation across studies"**

**Visual:**
- Panel A: General form Θ(μ) = E_μ[φ(Q)]
- Panel B: List of example functionals
- Panel C: Today's focus—correlation, with scatter plot of (ΔS(Q), ΔY(Q))

**Script:** "The framework is fully general. We estimate the expectation of any functional φ across the distribution μ of future studies. Examples: correlation of treatment effects across studies, probability that effects have the same sign, conditional means for specific effect ranges, proportion exceeding thresholds—whatever quantifies surrogate quality for your application. Today we'll focus on correlation as our running example, but the machinery works for any φ. And crucially, this is always a functional across studies, never across types or individuals within a study."

**Sources:**
- Paper estimand section
- Session notes 2026-04-17 (across-study paradigm)
- Framework generality

---

#### Slide 11: One Operationalization: Local Geometries
**Main point:** Local geometries are ONE way to define μ—uniform distribution on {Q : d(Q, P₀) ≤ λ}

**Content:**
- **The question:** How do we choose μ (the distribution over future studies)?

- **Many possible approaches:**
  - Expert elicitation: Ask domain experts which Q's are plausible
  - Historical data: If multiple past studies exist, μ based on empirical variation
  - Sensitivity analysis: Try multiple μ's, see how results change
  - **Local geometries:** Our approach today (conservative, non-informative)

- **Local geometry approach:**
  - Define U(P₀, λ; d) = {Q : d(Q, P₀) ≤ λ}
  - μ = Uniform(U(P₀, λ; d)) (all Q's within distance λ equally likely)
  - Parameters:
    - d: distance metric (TV, Wasserstein, KL, chi-squared, L2, ...)
    - λ: radius (how far future studies can deviate)
  - **Interpretation:** Treats all directions of deviation equally (conservative)

- **Why local geometries?**
  - Non-informative: No privileged directions
  - Flexible: Works with any distance metric d
  - Interpretable: λ directly controls deviation magnitude
  - Computationally feasible

**Visual:**
- Panel A: General question "How to choose μ?"
- Panel B: List of approaches (expert, historical, sensitivity, local geometry)
- Panel C: Geometric illustration—P₀ in center, U(P₀, λ) as ball, uniform μ

**Script:** "Now, how do we choose the distribution μ? There are several approaches. You could elicit expert opinions about plausible futures, use historical variation if multiple studies exist, or perform sensitivity analysis across multiple μ's. Our approach today—local geometries—provides a conservative, non-informative baseline. We define a ball: all distributions within distance λ of P₀. Then we use the uniform distribution on that ball, treating all directions of deviation equally. This is conservative because it doesn't privilege any particular direction of change. And it's flexible—you can use any distance metric that captures the deviations you care about."

**Sources:**
- Paper setting section (lines 83-109)
- Framework generality
- Local geometry as one operationalization

**Need:** Three-panel figure showing operationalization choices + geometry illustration

---

**Transition to Methodology:**

We've now defined the framework: a distribution μ over future studies Q, the general estimand E_μ[φ(Q)] for any functional φ, and local geometries as one way to operationalize μ. The next question: **How do we actually estimate this?**

---

### Part 3: Methodology (3-4 minutes, 3 slides)

#### Slide 12: The Estimator
**Main point:** Sample M future studies Q_m from U(P₀, λ; d), compute ΔS(Q_m), ΔY(Q_m) for each, estimate correlation

**Content:**
- **Algorithm:**
  1. Sample Q₁, ..., Qₘ from U(P₀, λ; d) via MCMC
  2. For each Qₘ, compute treatment effects via
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

#### Slide 13: Sampling Algorithm: Hit-and-Run MCMC
**Main point:** Uniform sampling from convex geometries via random walk

**Content:**
- **Hit-and-Run algorithm:**
  1. Start at current Q_t ∈ U(P₀, λ; d)
  2. Draw random direction v
  3. Compute line segment within U(P₀, λ; d)
  4. Sample uniformly along line → Q_{t+1}
  5. Repeat with burn-in

**Visual:** Illustration of hit-and-run on simplex with TV ball constraint, or convergence trace plot

**Script:** "To sample uniformly from the geometry, we use hit-and-run MCMC, a standard method for convex bodies. Start at a point, pick a random direction, move uniformly along the line segment that stays in the ball. After burn-in, this converges to uniform. We've validated convergence is essentially perfect."

**Sources:**
- Paper estimation section (lines 236-247)
- Exploration wrapup (R-hat validation)
- explorations/tv_ball_geometry/ results

**Need:** Hit-and-run visualization (adapt from exploration figures)

---

#### Slide 14: Inference: Asymptotic Theory and EIF
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

### Part 4: Two Approaches to Local Geometries (5-6 minutes, 5 slides)

#### Slide 15: Choosing the Local Geometry: Two Approaches
**Main point:** The geometry choice determines what types of future studies we consider—two natural approaches with complementary strengths

**Content:**
- **Recall:** Local geometry μ = Uniform(U(P₀, λ; d)) where U(P₀, λ; d) = {Q : d(Q, P₀) ≤ λ}

- **Key design choice: What space do we define Q over?**
  - Different spaces lead to different interpretations of "future study"
  - Trade-off: Interpretability vs. Robustness

- **Two natural approaches:**

  **Approach 1: X-Level Geometry** (Compositional changes)
  - Q defined over covariate distributions: Q(X)
  - Interpretation: Future studies differ in patient mix (more elderly, more severe disease)
  - Assumption: Treatment effect functions ΔS(X), ΔY(X) stay constant
  - **Strengths:** Clear interpretation, targets compositional transportability
  - **Weaknesses:** Requires X captures all effect modifiers, assumes mechanisms transport

  **Approach 2: Observation-Level Geometry** (General changes)
  - Q defined over individual observations: Q(individual)
  - Interpretation: Future studies differ in individual-level composition (includes within-X variation)
  - No assumption about which variables drive effects
  - **Strengths:** Robust to unmeasured effect modifiers, no mechanistic assumptions
  - **Weaknesses:** Includes idiosyncratic noise, more conservative

- **Complementary evidence:**
  - X-level: "If my X's capture effect modification and mechanisms transport..."
  - Observation-level: "Even with unmeasured heterogeneity and noise..."
  - Report both to bracket the answer

**Visual:** Two-panel comparison table:
- Panel A: X-level (Definition, Interpretation, Strengths, Weaknesses)
- Panel B: Observation-level (Definition, Interpretation, Strengths, Weaknesses)

**Script:** "Now we need to choose the local geometry. Recall: we define Q over some space within distance λ of P₀. The key question: what space? Two natural approaches emerge. X-level geometry defines Q over covariate distributions—future studies differ in patient mix. This gives clear interpretation for compositional changes, but assumes treatment effect functions transport. Observation-level geometry defines Q over individuals—future studies differ in individual-level composition, including noise. This is robust to unmeasured heterogeneity but more conservative. These provide complementary evidence: X-level tells you about compositional transportability under strong assumptions, observation-level provides a conservative bound even with unmeasured factors. We'll examine both."

**Sources:**
- Session notes 2026-04-17 (X-level vs observation-level distinction)
- Framework generality

**Need:** Two-panel comparison table figure

---

#### Slide 16: X-Level Geometry: Details and Assumptions
**Main point:** X-level geometry reweights covariate distributions—requires strong assumptions about effect modification

**Content:**
- **Definition:** U_X(P₀, λ) = {Q over X-distributions: TV(Q_X, P₀,X) ≤ λ}
  - What changes: Covariate distribution P(X) (compositional shifts)
  - What stays constant: Treatment effect functions ΔS(X), ΔY(X)
  - Interpretation: Surrogate quality under compositional changes (different patient mix)

- **Assumptions:**
  1. **X completely determines effect heterogeneity** (no unmeasured effect modifiers U)
  2. **Mechanisms transport** (functions ΔS(X), ΔY(X) stable across studies)

- **When appropriate:**
  - Well-chosen X captures key effect modifiers (age, disease severity, biomarkers)
  - Future studies involve same mechanisms, different compositions
  - Large-sample transportability (noise averages out)

**Visual:** Two panels: (1) Compositional shift P₀(X) → Q(X), (2) Assumption list with checkmarks

**Script:** "X-level geometry reweights across covariate distributions—future studies differ in patient mix but the treatment effect functions stay constant. This requires strong assumptions: X must completely determine effect heterogeneity, and the mechanisms must transport. When X captures key effect modifiers and future studies involve the same biology just with different compositions, this is plausible. With well-chosen X—age, disease severity, relevant biomarkers—often reasonable."

**Sources:**
- Session notes 2026-04-17 (lines 32-38, 128-137)

---

#### Slide 17: X-Level Analysis: What to Expect
**Main point:** X-level targets compositional transportability—when DGP matches assumptions, should recover high correlation

**Content:**
- **What X-level should show (when assumptions hold):**
  - If treatment effects truly correlate across types (high ρ)
  - And X captures effect modification
  - And mechanisms transport
  - Then: X-level correlation should be high (≈ 0.8-0.9)

- **Interpretation:**
  - High X-level correlation → surrogate transports under compositional changes
  - Low X-level correlation → even compositional changes break surrogacy
  - This is the "best case" scenario (strong assumptions)

- **Simulation validation needed:**
  - Comprehensive simulation study planned (500-1000 replications)
  - Will test: performance under assumption violations, coverage properties, power
  - Results forthcoming

**Visual:** Conceptual diagram showing: True type-level correlation → X-level recovers it (when assumptions hold)

**Script:** "What should X-level analysis show when assumptions hold? If treatment effects truly correlate across types, X captures effect modification, and mechanisms transport, then X-level should recover high correlation—typically 0.8 to 0.9. This represents the best-case scenario for compositional transportability. We're conducting comprehensive simulation validation with 500-1000 replications to verify these properties and test performance under assumption violations."

**Sources:**
- Theoretical expectations from framework
- Session notes 2026-04-17 (expected X-level behavior)

**Note:** SIMULATION RESULTS REMOVED - Need comprehensive sims with 500-1000 reps before presenting results

---

#### Slide 18: Observation-Level Geometry: How It Differs
**Main point:** Observation-level treats individuals as unique, including unmeasured heterogeneity—fundamentally different from X-level

**Content:**
- **Observation-level definition:** U_obs(P₀, λ) = {Q over individuals: TV(Q, P₀) ≤ λ}
  - Each person (X, S, Y) is unique
  - Allows unmeasured effect modifiers U and idiosyncratic variation ε_i
  - Most general distributional changes

- **Direct comparison:**

  | Aspect | X-level (Compositional) | Observation-level (General) |
  |--------|------------------------|----------------------------|
  | What changes | Reweights types/strata | Resamples individuals |
  | Variation | Between-X only | Between-X + within-X |
  | Formula | ΔS(Q) = Σ Q_X(x)·ΔS(x) | ΔS(Q) = Σ Q(i)·[ΔS(X_i)+ε_i] |
  | Appropriate for | Compositional changes | General changes, robustness |

**Visual:** Two-panel schematic: X-level (discrete types, reweighting) vs Observation-level (individuals as points, resampling with noise)

**Script:** "Observation-level treats individuals as unique and resamples them. This allows unmeasured heterogeneity and noise—fundamentally different from X-level. X-level reweights types, capturing only between-X variation—the signal. Observation-level resamples individuals, including both signal and within-X noise. This makes observation-level more robust but also conflates signal with noise."

**Sources:**
- Session notes 2026-04-17 (lines 138-169)

**Need:** Two-panel schematic figure (2 hours, Step 9 of plan)

---

#### Slide 19: Observation-Level Analysis: What to Expect
**Main point:** Observation-level includes both signal and noise—expect lower correlation than X-level due to attenuation

**Content:**
- **What observation-level should show:**
  - Same DGP as X-level (high type-level correlation)
  - X-level: Recovers high correlation (signal only)
  - Observation-level: Should show lower correlation
  - Why lower? Includes within-X variation (noise attenuation)

- **Theoretical prediction:**
  - If reliability ≈ 0.5 (half signal, half noise)
  - And X-level correlation = 0.9 (signal)
  - Then observation-level correlation ≈ 0.45-0.65 (attenuated by noise)

- **This is expected, not a problem:**
  - Observation-level is more conservative
  - Provides lower bound when X assumptions uncertain
  - Both approaches provide complementary evidence

- **Simulation validation needed:**
  - Comprehensive study planned (500-1000 replications)
  - Will test: noise attenuation predictions, reliability estimation, robustness
  - Results forthcoming

**Visual:** Conceptual diagram showing: Signal + Noise → Lower correlation than signal alone

**Script:** "What should observation-level show? With the same DGP, observation-level should give lower correlation than X-level because it includes within-X noise. If half the variation is signal and half is noise—reliability around 0.5—then a signal correlation of 0.9 would attenuate to around 0.45 to 0.65. This isn't a problem—it's expected. Observation-level provides a conservative bound. Comprehensive simulation validation is underway."

**Sources:**
- Theoretical prediction from attenuation formula (inst/presentation/theory-supplements.md)
- Session notes 2026-04-17 (noise attenuation)

**Note:** SIMULATION RESULTS REMOVED - Need comprehensive sims with 500-1000 reps before presenting results

---

### Part 5: Theoretical Comparison (2 minutes, 2 slides)

#### Slide 20: The Noise Attenuation Problem
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

#### Slide 21: Guidance: Which Geometry to Use?
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

### Part 6: Practical Use and Conclusion (2 minutes, 2-3 slides)

#### Slide 22: How to Use in Practice
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
- **Software implementation:**
  - R package in development
  - Functions for X-level and observation-level analysis
  - Built-in MCMC sampling and EIF-based inference
  - [Repository/documentation forthcoming]
- **Sample size considerations:**
  - Observed data: n ≥ 500 for stable correlation estimates
  - MCMC samples: M = 100-500 (larger for tighter CIs)
  - Bootstrap replications: B = 200-500 for variance estimation

**Visual:** Line plot showing correlation vs λ, with two examples (robust: flat, fragile: steep decline)

**Script:** "In practice, fit the model over a range of λ values—0.05, 0.10, 0.15, 0.20. For each, sample future studies, compute correlations, get confidence intervals. Then plot correlation versus λ. A flat line means the surrogate is robust—it works even for fairly dissimilar studies. A steep decline means it's fragile—only works for studies very close to P₀. Approve the surrogate if correlation stays high over a meaningful range."

**Sources:**
- Work plan Step 8: λ-robustness analysis
- Common sense from framework

**Need:** λ-robustness plot (1.5 hours, Step 8 of plan)

---

#### Slide 23: Summary
**Main point:** General framework for surrogate transportability via local geometries; X-level (compositional) vs observation-level (general) provide complementary evidence

**Content:**
- **Key contributions:**
  1. General framework for any distance metric d
  2. X-level: High correlation under compositional changes (strong assumptions)
  3. Observation-level: Conservative bound under general changes (robust)
  4. Noise attenuation explains gap via reliability coefficient
- **Practical guidance:**
  - Report both X-level and observation-level
  - Compute reliability to understand gap
  - Test over range of λ values
- **Contrast with traditional methods:**
  - We **evaluate** transportability, not **assume** it

**Visual:** Clean slide with 3-5 key bullets, no overwhelming text

**Script:** "To summarize: we've introduced a general framework for evaluating surrogate transportability using local geometric analysis. X-level analysis assumes compositional changes and recovers high correlation. Observation-level is more general and robust but shows lower correlation due to noise attenuation. The reliability coefficient quantifies this gap. Report both analyses to provide complementary evidence about surrogate quality."

---

#### Slide 24 (Optional): Extensions and Future Work
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
