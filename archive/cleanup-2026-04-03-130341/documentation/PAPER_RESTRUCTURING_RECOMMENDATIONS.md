# Critical Review and Restructuring Recommendations

**Date:** 2026-03-25
**Context:** Following implementation of concordance functional with closed-form DRO solutions and comprehensive methods comparison

---

## Executive Summary

Today's work fundamentally reframes the paper's contribution. The current manuscript pitches the approach as "eliminating dependence on μ" via minimax bounds. The real innovation is **evaluating (not assuming) transportability** with computational efficiency that makes it practical. This distinction should drive the restructuring.

**Core insight:** We're not just another surrogate validation method with different assumptions—we're the only method that explicitly evaluates whether surrogate knowledge transports to future studies, and we do it with computational efficiency that enables real-time decision-making.

---

## Current State of the Paper

### Current Pitch
- **Primary frame:** Random probability measure framework with minimax bounds
- **Technical focus:** Eliminating μ-dependence
- **Positioning:** Compared to traditional methods on assumptions (Table 1)
- **Computational angle:** Not emphasized

### Current Structure
1. **Introduction** — Positions against traditional methods
2. **Setting** — Random probability measure, perturbation model
3. **Minimax bounds** — Worst-case inference
4. **Inference for ε-close statements** — Grid search
5. **Simulation study** — Validation
6. **Theoretical properties** — RF-ensemble approximation

### What's Missing
1. **Core distinction:** Evaluate vs assume transportability (mentioned implicitly but not emphasized)
2. **Computational innovation:** No mention of concordance or closed-form solutions
3. **Methods comparison:** Traditional methods not evaluated empirically
4. **Coverage under violations:** Critical finding (95% vs 70-75%) not shown
5. **Practical guidance:** When to use minimax vs traditional methods
6. **Trade-off analysis:** Speed vs distributional information

---

## Critical Issues with Current Framing

### Issue 1: Buried Lead
**Problem:** The introduction says "A central motivation for surrogate evaluation is use in future trials or in new populations" (line 44) but doesn't emphasize that traditional methods **assume** this works while we **evaluate** it.

**Evidence:** Table 1 (Introduction) compares methods on "assumptions" and "data requirements" but doesn't have a column for "Does it evaluate or assume transportability?"

**Impact:** Readers may view this as "yet another surrogate method with different assumptions" rather than "the only method that checks if surrogate knowledge actually transports."

### Issue 2: Minimax as Technical Detail, Not Scientific Contribution
**Problem:** Section 3 frames minimax as eliminating μ-dependence (a technical nuance) rather than providing worst-case guarantees for **prospective decision-making**.

**Current text:** "The inference framework in Section 2 depends on a choice of innovation distribution μ... We now eliminate this μ-dependence by providing worst-case bounds" (line 330-333)

**Better framing:** "For prospective decision-making, we need conservative guarantees that hold even when future studies differ from the current study in unknown ways. We provide worst-case bounds that..."

**Impact:** Minimax sounds like a technical fix for a nuisance parameter rather than the core scientific contribution.

### Issue 3: No Empirical Comparison to Traditional Methods
**Problem:** Table 1 compares methods conceptually but doesn't show what happens when transportability is violated.

**Missing evidence:**
- Minimax maintains 95% coverage under violations
- PTE, within-study, principal stratification, mediation show 70-75% undercoverage
- This is the **key scientific finding** but it's not in the paper

**Impact:** Without empirical evidence, the comparison feels theoretical. The actual performance gap is dramatic and should be shown.

### Issue 4: Computational Efficiency Not Discussed
**Problem:** The paper mentions grid search computational cost (line 412-415: "approximately 90,000 treatment effect computations per baseline, taking 5-10 seconds") but doesn't discuss:
- Concordance functional with closed-form solutions
- 9-487x speedup over correlation-based minimax
- Enables real-time inference and large-scale sensitivity analyses
- Trade-off: speed vs distributional information

**Impact:** Misses opportunity to highlight practical innovation. Without concordance, the method seems computationally expensive; with it, it's faster than most alternatives while maintaining robustness.

### Issue 5: False Dichotomy with Traditional Methods
**Problem:** The introduction positions traditional methods as competitors with different assumptions, implying "choose one."

**Reality:** Methods answer different questions:
- **Minimax:** "Will the surrogate work in future studies with unknown shifts?"
- **Traditional:** "Does the surrogate work in this study?"

These are complementary, not competing.

**Impact:** Reviewers may object "but PTE/mediation are standard and work fine" without recognizing that those methods assume (not evaluate) transportability.

---

## Restructuring Recommendations

### Part (i): How to Pitch the Approach

#### New Elevator Pitch (30 seconds)
> "Surrogate validation for prospective decision-making requires evaluating whether surrogate knowledge will transport to future studies with unknown population shifts. Existing methods assume transportability; we evaluate it by computing worst-case bounds over plausible distributional shifts. A key computational innovation—concordance functional with closed-form DRO solutions—provides 9-487× speedup, enabling real-time inference while maintaining conservative guarantees. Simulations show our approach maintains 95% coverage under transportability violations where traditional methods achieve only 70-75%."

#### Three Pillars (What to Emphasize)

**Pillar 1: Scientific Contribution**
- **Gap:** Parast et al. (2024) identified "limited work on transportability of surrogate knowledge"
- **Innovation:** Only method that **evaluates** (not assumes) transportability
- **Evidence:** Maintains 95% coverage when violated; traditional methods undercover

**Pillar 2: Computational Innovation**
- **Challenge:** Minimax inference was computationally expensive (seconds to minutes per analysis)
- **Innovation:** Concordance functional with closed-form DRO solutions (Ben-Tal 2013; Esfahani & Kuhn 2018)
- **Impact:** 9-487× speedup enables real-time inference and large-scale sensitivity analyses

**Pillar 3: Practical Guidance**
- **Insight:** Different methods answer different questions (complementary, not competing)
- **Trade-offs:** Speed vs distributional information; conservative vs optimistic bounds
- **Recommendations:** When to use minimax (prospective decisions) vs traditional (descriptive analysis)

#### Opening Hook (First Paragraph Rewrite)

**Current opening:**
> "A central question in the evaluation of surrogate markers is whether the surrogate can replace the gold-standard outcome in future trials or in new populations."

**Recommended opening:**
> "Surrogate markers promise to accelerate clinical trials by replacing expensive or long-term outcomes with faster-measured alternatives. But a surrogate validated in one study may fail in another due to population differences, treatment effect heterogeneity, or unmeasured confounding. Parast et al. (2024) identified 'limited work on transportability of surrogate knowledge from one study to another' as a critical gap. Existing validation methods—proportion of treatment effect (PTE), principal stratification, causal mediation—assume that surrogate relationships transport across studies. We present the first framework to explicitly evaluate this transportability by computing worst-case bounds over plausible distributional shifts. Our approach provides conservative guarantees appropriate for prospective decision-making while maintaining computational efficiency through closed-form distributional robustness optimization."

**Why this works:**
- Immediately establishes the problem (surrogates may not transport)
- Cites the gap (Parast 2024)
- States the key distinction (evaluate vs assume)
- Positions the contribution (first to evaluate transportability)
- Mentions computational efficiency upfront

---

### Part (ii): How to Structure the Paper

#### Recommended Structure

**1. Introduction [MAJOR REVISION]**
- Current: 1.5 pages comparing assumptions
- Recommended: 2-2.5 pages with stronger framing
  - Para 1: Opening hook (see above)
  - Para 2: Existing methods and their limitations (emphasize assumption of transportability)
  - Para 3: Our approach—evaluate transportability via minimax + computational innovation
  - Para 4: Contributions summary (scientific + computational + practical)
  - **New Table 1:** Add "Transportability" column (Evaluated vs Assumed)

**2. Setting [MINOR REVISION]**
- Keep current structure (random probability measure, perturbation model)
- Add 1 paragraph at end: "Treatment effect heterogeneity as the fundamental object"
  - Clarifies that types are discretization of continuous τ(X)
  - Justifies why concordance E[τ_S·τ_Y] is natural functional
  - Leads into Section 3

**3. Minimax Bounds [MINOR REVISION]**
- Keep current technical development
- Reframe opening (Issue 2 above):
  - Current: "eliminating dependence on μ"
  - Recommended: "conservative guarantees for prospective decisions"
- Add **subsection 3.7: Computational Implementation**
  - Concordance functional: closed-form solutions
  - TV-ball: φ* = E_P0[τ_S·τ_Y] - λ·max|τ_j^s·τ_j^y| (instant)
  - Wasserstein: 1-parameter dual (seconds, not minutes)
  - Speedup: 9-487× faster than correlation-based minimax
  - Trade-off: Distributional information (sampling) vs speed (closed-form)
  - **New Figure:** Computation time comparison (log scale)

**4. Inference for ε-close statements [KEEP]**
- No changes needed

**5. Simulation Study [MAJOR ADDITION]**
- Keep current validation results (subsections 5.1-5.2)
- **Add subsection 5.3: Comparison to Traditional Methods**
  - Brief description of PTE, within-study correlation, mediation, principal stratification
  - Key distinction table (evaluate vs assume transportability)
  - **Simulation design:**
    - Scenario A: Transportable (no covariate shift)
    - Scenario B: Violated (covariate shift)
  - **Results:**
    - Coverage under transportability: All methods ~95%
    - Coverage under violations: Minimax 95%, traditional 70-75%
    - Performance comparison table (from FINAL_METHODS_COMPARISON_RESULTS.md)
  - **New Figure:** Coverage probability by method and scenario (bar chart)
  - **New Table:** Performance benchmarks (time, memory, coverage)

**6. Discussion [NEW SECTION]**
- **Subsection 6.1: Position in Literature**
  - Addresses Parast et al. (2024) gap
  - Only method evaluating (not assuming) transportability
  - Complements traditional methods (different questions)
- **Subsection 6.2: Computational Innovation**
  - Concordance functional with closed-form DRO
  - Enables previously infeasible applications (real-time, large-scale)
  - Trade-off: Speed vs distributional information (hybrid approaches)
- **Subsection 6.3: Practical Recommendations**
  - Decision tree: When to use minimax vs traditional
  - Workflow: Screen with concordance → detailed analysis with correlation → compare to traditional
  - Interpreting the gap: Minimax << traditional = high transportability concern
- **Subsection 6.4: Limitations and Extensions**
  - Current: Finite support assumption (continuous extensions)
  - Current: Treatment effect heterogeneity (more complex mediating pathways)
  - Future: Multiple surrogates, meta-analysis, Bayesian implementations
  - Future: Real-time monitoring, interactive web tools

**7. Theoretical Properties [KEEP]**
- No changes needed (RF-ensemble approximation results)

**8. Conclusion [NEW SECTION, 0.5 pages]**
- Restate core contributions
- Emphasize evaluate vs assume distinction
- Call to action: Use minimax for prospective decisions, traditional for descriptive

---

## Specific Text Changes

### Change 1: Introduction, Table 1 (Add Column)

**Current table (reproduced from line 58-66):**
```latex
\begin{tabular}{llll}
\toprule
Approach & Inferential target & Main assumptions & Data \\
\midrule
Meta-analytic & Trial-level association & Multiple trials; homogeneity & Multiple studies \\
Principal stratification & Principal causal effects & Principal strata structure; often strong independence & Single/multiple \\
PTE & Proportion of effect explained & Monotonicity (to avoid surrogate paradox) & Single study \\
Mediation & Natural direct/indirect effects & No unmeasured confounding (M–Y; A–M–Y) & Single study \\
This approach & Functionals of distribution of studies & Perturbation model; finite support (estimation) & Single study \\
\bottomrule
\end{tabular}
```

**Recommended table:**
```latex
\begin{tabular}{lllll}
\toprule
Approach & Inferential target & Transportability & Main assumptions & Data \\
\midrule
Meta-analytic & Trial-level association & \textbf{Assumed} & Multiple trials; homogeneity & Multiple \\
Principal strat. & Principal causal effects & \textbf{Assumed} & Strata structure; cross-world indep. & Single/multiple \\
PTE & Proportion explained & \textbf{Assumed} & Monotonicity (avoid paradox) & Single \\
Mediation & Direct/indirect effects & \textbf{Assumed} & No unmeas. confounding (M–Y) & Single \\
\midrule
\textbf{Minimax (ours)} & \textbf{Worst-case across studies} & \textbf{Evaluated} & Perturbation model & Single \\
\bottomrule
\end{tabular}
```

**Rationale:** Makes the key distinction immediately visible. "Evaluated" vs "Assumed" is the core contribution.

---

### Change 2: Section 3 Opening (Reframe)

**Current text (lines 328-334):**
> "The inference framework in Section 2 depends on a choice of innovation distribution μ. The functional φ(F_λ) represents the expected surrogate quality over μ, which depends on our belief about which future studies are plausible. If μ concentrates near P₀, then φ(F_λ) ≥ c provides only weak evidence (the surrogate is good for futures resembling the current study). A more stringent test uses a broad μ (e.g., uniform Dirichlet), but this still requires specifying μ correctly. We now eliminate this μ-dependence by providing worst-case bounds that hold for all innovation distributions in a plausible class M."

**Recommended text:**
> "For prospective decision-making about surrogate use in future studies, we need conservative guarantees that hold even when the future study population differs from the current study in unknown ways. Traditional surrogate validation methods assume that the surrogate–outcome relationship observed in the current study will transport to future studies. We take a different approach: we explicitly evaluate transportability by computing worst-case bounds over a class of plausible distributional shifts.
>
> Technically, this is achieved by eliminating dependence on the innovation distribution μ. While the inference framework in Section 2 computes expected surrogate quality E_μ[φ(Q)] for a specified μ, we instead compute inf_μ φ(Q) and sup_μ φ(Q) over a class M of plausible innovation distributions. If the worst-case bound inf_μ φ(Q) exceeds a threshold c, the surrogate is guaranteed to meet the threshold for all distributional shifts in M—a conservative guarantee appropriate for prospective decisions."

**Rationale:** Leads with the scientific motivation (prospective decisions, conservative guarantees) before the technical detail (eliminating μ).

---

### Change 3: Add Subsection 3.7 (Computational Implementation)

**Location:** After subsection 3.6 (Comparison with standard method), before Section 4

**New subsection 3.7:**

```latex
\subsection{Computational implementation via concordance functional}

The minimax computation described in subsection 3.3 requires optimizing over a grid of Dirichlet parameters and vertex schemes, with M Monte Carlo draws per grid point. For the correlation functional, this is computationally expensive: with K=40 Dirichlet points, 50 vertices, M=1000 draws per scheme, and J=16 discretization schemes, a single λ value requires approximately 1.5 million treatment effect computations, taking 30-60 seconds on standard hardware.

We now introduce a computational innovation that reduces this cost by two orders of magnitude while maintaining identical robustness guarantees: the \emph{concordance functional} with closed-form distributional robustness optimization (DRO) solutions.

\subsubsection{Concordance as a linear functional}

Consider the concordance functional
\[
    \phi_{\text{conc}}(\Q) = \E_{\Q}[\Delta_S(\Q) \cdot \Delta_Y(\Q)]
\]
which measures the expected product of treatment effects across studies. This functional is closely related to correlation:
\[
    \text{Cor}(\Delta_S, \Delta_Y) = \frac{\phi_{\text{conc}}(\cF)}{\sqrt{\Var(\Delta_S) \Var(\Delta_Y)}}
\]
and inherits its interpretation: positive concordance indicates that treatment effects move together (both benefit or both harm); negative concordance indicates opposition.

The key property is that concordance is \emph{linear} at the type level. Under discretization into J types (bins), let τ_j^s and τ_j^y denote the type-j treatment effects on S and Y. The concordance functional becomes
\[
    \phi_{\text{conc}}(q) = \sum_{j=1}^J q_j \cdot (τ_j^s \cdot τ_j^y) = \sum_{j=1}^J q_j h_j
\]
where $h_j = τ_j^s · τ_j^y$ and q is the type distribution. This is a \emph{linear functional} of q, enabling closed-form DRO solutions.

\subsubsection{Closed-form solution for TV-ball}

For the TV-ball minimax problem
\[
    \phi_*(\lambda) = \inf_{\Q: d_{\text{TV}}(\Q, \PP_0) \leq \lambda} \phi_{\text{conc}}(\Q)
\]
the distributional robustness optimization literature (Ben-Tal et al. 2013) provides an exact closed-form solution for linear functionals:
\[
    \phi_*(\lambda) = \E_{\PP_0}[h] - \lambda \cdot \|h\|_\infty = \sum_{j=1}^J p_{0j} h_j - \lambda \cdot \max_j |h_j|
\]
where p_0 is the empirical type distribution. This formula requires only:
1. Computing type-level treatment effects τ_j^s, τ_j^y (one pass through data)
2. Computing the product h_j = τ_j^s · τ_j^y (J multiplications)
3. Taking maximum absolute value (J comparisons)

\textbf{Computational cost:} O(J) = O(16) ≈ 16 operations vs O(M×n) = O(2000×500) ≈ 1,000,000 for correlation-based sampling. This is an algorithmic speedup of 60,000×, yielding wall-clock speedups of 9-12× in practice (4ms vs 38ms).

\subsubsection{Dual optimization for Wasserstein ball}

For the Wasserstein DRO problem
\[
    \phi_*(\lambda_W) = \inf_{\Q: W_2(\Q, \PP_0) \leq \lambda_W} \phi_{\text{conc}}(\Q)
\]
the dual formulation (Esfahani & Kuhn 2018) reduces the problem to a 1-parameter optimization over the dual variable γ ≥ 0:
\[
    \phi_*(\lambda_W) = \sup_{γ \geq 0} \left\{ -γ\lambda_W^2 + \sum_{j=1}^J p_{0j} \min_i \{h_i + γ C[i,j]\} \right\}
\]
where C is the type-to-type cost matrix (e.g., squared Euclidean distance in covariate space).

\textbf{Computational cost:} 1-dimensional optimization using Brent's method requires O(J^2 log(1/ε)) ≈ 256 evaluations vs O(M×J^3) ≈ 8,192,000 for sampling-based optimal transport. Wall-clock speedup: 487× (4ms vs 1963ms).

\subsubsection{Trade-off: Speed vs distributional information}

The closed-form solutions provide only the \emph{minimum} (worst-case bound), not the full distribution of φ(Q) over Q ∈ B_λ(P_0). Sampling-based approaches provide:
- Mean, median, quantiles (5th, 25th, 75th, 95th percentiles)
- Variance and distributional shape
- Risk profiling for different decision contexts

For most applications, the worst-case bound (minimum) is sufficient for decision-making. However, when risk profiling is needed (e.g., portfolio management across multiple studies with varying risk tolerance), the full distribution adds value. A hybrid approach—screening with closed-form concordance, then detailed sampling at critical λ values—balances efficiency and information content.

\subsubsection{Performance comparison}

Table X shows computational performance for n=500, J=16, comparing concordance and correlation functionals for TV-ball and Wasserstein ball minimax inference.

\begin{table}[h]
\centering
\caption{Computational performance comparison (n=500, J=16 types, M=2000 samples where applicable)}
\begin{tabular}{lcccc}
\toprule
Method & Functional & Time & Memory & Info \\
\midrule
Minimax-TV & Concordance & \textbf{4.2 ms} & 1.2 MB & min only \\
Minimax-TV & Correlation & 37.5 ms & 54.8 MB & full dist \\
Minimax-W & Concordance & \textbf{4.0 ms} & 0.7 MB & min only \\
Minimax-W & Correlation & 1963 ms & 208 MB & full dist \\
\midrule
\multicolumn{5}{l}{\emph{Speedup: 9× (TV), 487× (Wasserstein)}} \\
\bottomrule
\end{tabular}
\end{table}

For large-scale simulations (1000 sensitivity analyses): concordance completes in 4 seconds; correlation requires 33 minutes (TV) or 33 hours (Wasserstein).

\subsubsection{When to use concordance vs correlation}

\textbf{Use concordance when:}
\begin{itemize}
    \item Computational efficiency is critical (large simulations, real-time inference)
    \item Only worst-case bound needed for decision
    \item Screening many λ values (sensitivity analysis)
\end{itemize}

\textbf{Use correlation when:}
\begin{itemize}
    \item Reporting to clinical audiences (correlation more familiar)
    \item Need full distribution for risk profiling
    \item Single analysis (speed not critical)
\end{itemize}

\textbf{Hybrid approach:}
\begin{enumerate}
    \item Screen λ ∈ {0.1, 0.15, ..., 0.5} with concordance (fast)
    \item Identify critical λ values (near decision boundary)
    \item Detailed distributional analysis at critical λ with correlation (rich info)
\end{enumerate}

For the simulations in Section 5, we use concordance for all minimax computations to enable comprehensive sensitivity analyses that would otherwise be computationally infeasible.
```

**Rationale:**
- Introduces concordance with full mathematical justification
- Shows exact speedup with empirical benchmarks
- Documents trade-off (speed vs information)
- Provides practical guidance on when to use each
- Justifies why simulations use concordance

---

### Change 4: Add Subsection 5.3 (Comparison to Traditional Methods)

**Location:** After subsection 5.2 (Results), before Section 6

**New subsection 5.3:**

```latex
\subsection{Comparison to traditional surrogate evaluation methods}

We now compare the minimax approach to established surrogate validation frameworks: proportion of treatment effect (PTE) \citep{chen2003pte}, within-study correlation, principal stratification \citep{frangakis2002principal}, and causal mediation \citep{vanderweele2015mediation}. A critical distinction: \textbf{minimax explicitly evaluates transportability by computing worst-case bounds}, while traditional methods \textbf{assume that surrogate relationships transport across studies}.

\subsubsection{Traditional methods: Brief review}

\paragraph{Proportion of treatment effect (PTE).}
Estimates the proportion of the treatment effect on Y that is "explained" by the treatment effect on S:
\[
    \text{PTE} = \frac{\text{Cov}(\Delta_Y, \Delta_S)}{\text{Var}(\Delta_S)}
\]
A PTE near 1 suggests the surrogate captures the full treatment effect. However, PTE assumes this relationship will hold in future studies and requires monotonicity assumptions to avoid the "surrogate paradox" where a good surrogate in one study fails in another.

\paragraph{Within-study correlation.}
Measures the observed correlation Cor(S,Y) in the current study. High correlation may indicate a good surrogate, but this within-study association can differ from the across-study correlation of treatment effects when there are unmeasured confounders or when treatment effect heterogeneity is present.

\paragraph{Principal stratification.}
Defines principal causal effects within strata defined by joint potential outcomes {S(0), S(1)}. This requires strong assumptions on the joint distribution of counterfactuals, often including cross-world independence. The approach identifies subgroups where treatment effects differ, but validation for \emph{new} populations requires assuming these strata definitions transport.

\paragraph{Causal mediation.}
Decomposes the total effect into natural direct and indirect effects through the surrogate. This requires no unmeasured confounding between S and Y, which is difficult to verify. Like PTE, mediation provides within-study decomposition but assumes the mediation structure holds in future studies.

\paragraph{Common limitation.}
All four approaches \textbf{assume} that relationships estimated in the current study will hold in future studies. They do not explicitly evaluate this transportability assumption.

\subsubsection{Simulation design: Transportable vs violated scenarios}

We compare the five approaches in two scenarios:

\textbf{Scenario A (Transportable):} Future studies drawn from F_λ with λ=0.3 under uniform Dirichlet innovation. Treatment effect heterogeneity is moderate (CV=0.3 for both τ_S and τ_Y), and the correlation of treatment effects across types is ρ = 0.85. All methods should perform well here since transportability holds.

\textbf{Scenario B (Violated):} Future studies experience covariate shift: the distribution of X changes such that types with weak or opposite-signed treatment effects are upweighted. This violates the transportability assumption underlying traditional methods. Specifically, we induce shift by reweighting types according to w_j ∝ exp(-0.5 · τ_j^s · τ_j^y), favoring types where effects are misaligned. The minimax approach accounts for such shifts (they are in the TV-ball); traditional methods do not.

For each scenario, we:
1. Generate 1000 future studies under the specified shift
2. For each method, estimate surrogate quality and construct 95% confidence intervals
3. Assess coverage: does the CI contain the true value in 95% of simulations?

Sample size n=500, J=16 types, B=200 bootstrap replicates for minimax.

\subsubsection{Results: Coverage under transportability violations}

Table X shows coverage probability for each method in the two scenarios.

\begin{table}[h]
\centering
\caption{Coverage probability: Transportable vs violated scenarios}
\begin{tabular}{lccc}
\toprule
Method & Transportable (A) & Violated (B) & Maintains Coverage? \\
\midrule
\textbf{Minimax (Concordance)} & 94.8\% & \textbf{95.2\%} & \textbf{Yes ✓} \\
\textbf{Minimax (Correlation)} & 95.1\% & \textbf{94.9\%} & \textbf{Yes ✓} \\
PTE & 94.7\% & 74.3\% & No ✗ \\
Within-Study Correlation & 95.0\% & 69.8\% & No ✗ \\
Principal Stratification & 94.9\% & 76.1\% & No ✗ \\
Mediation & 95.2\% & 73.5\% & No ✗ \\
\bottomrule
\end{tabular}
\end{table}

\textbf{Key finding:} When transportability holds (Scenario A), all methods achieve nominal coverage. When transportability is violated (Scenario B), \textbf{only minimax maintains 95% coverage}; traditional methods show 20-25 percentage point undercoverage.

Figure X visualizes these results as a bar chart with 95% reference line.

\subsubsection{Computational performance}

Table Y compares computational performance on the same validation scenarios.

\begin{table}[h]
\centering
\caption{Computational performance (n=500, single analysis)}
\begin{tabular}{lccl}
\toprule
Method & Time & Memory & Question Answered \\
\midrule
\textbf{Minimax-TV Conc} & \textbf{4.2 ms} & 1.2 MB & Worst-case across studies? \\
\textbf{Minimax-W Conc} & \textbf{4.0 ms} & 0.7 MB & Worst-case across studies? \\
Minimax-TV Corr & 37.5 ms & 54.8 MB & Worst-case across studies? \\
Minimax-W Corr & 1963 ms & 208 MB & Worst-case across studies? \\
\midrule
PTE & 0.09 ms & 0.1 MB & How much explained (this study)? \\
Within-Study Corr & 0.04 ms & <0.1 MB & Association (this study)? \\
Princ. Strat. & ~50 ms & ~5 MB & Stratum effects (this study)? \\
Mediation & ~10 ms & ~1 MB & Direct/indirect (this study)? \\
\bottomrule
\end{tabular}
\end{table}

Traditional methods are faster when only describing the current study. However, for evaluating transportability to future studies:
- Concordance-based minimax is 9-487× faster than correlation-based minimax
- Concordance achieves 4ms inference time, making it practical for real-time decision support
- Traditional methods cannot evaluate transportability (not designed for this question)

\subsubsection{Interpretation: Complementary tools, not competing}

The comparison reveals that methods answer \emph{different questions}:

\begin{itemize}
    \item \textbf{Minimax:} "Will the surrogate work in future studies with unknown population shifts?" Provides conservative bounds appropriate for prospective decision-making.

    \item \textbf{Traditional:} "Does the surrogate work in the current study?" Descriptive analysis of within-study relationships.
\end{itemize}

These are complementary, not competing. In practice, we recommend:
\begin{enumerate}
    \item \textbf{Screen with minimax-concordance} (4ms, worst-case bounds) to assess transportability
    \item \textbf{Report minimax-correlation} (38ms, familiar functional) if needed for clinical audiences
    \item \textbf{Compare to traditional methods} (PTE, within-study) to quantify the "transportability gap"
    \item \textbf{Interpret the gap:} If minimax << traditional, high transportability concern; use minimax for conservative planning
\end{enumerate}

The width of the gap between minimax and traditional estimates provides diagnostic information about transportability risk. A small gap suggests low concern; a large gap flags that surrogate performance may degrade in future populations.

\subsubsection{When to use minimax vs traditional methods}

\textbf{Use minimax when:}
\begin{itemize}
    \item \textbf{Prospective decision-making} (planning future trials, regulatory approval)
    \item \textbf{Unknown future populations} (transportability cannot be assumed)
    \item \textbf{Conservative guarantees required} (worst-case robustness)
    \item \textbf{Sensitivity analyses} (many λ values, computational efficiency via concordance)
\end{itemize}

\textbf{Use traditional methods when:}
\begin{itemize}
    \item \textbf{Descriptive analysis} (understanding current study)
    \item \textbf{Transportability justified} (future population closely resembles current)
    \item \textbf{Quick assessment} (sub-millisecond inference)
    \item \textbf{Mechanism investigation} (principal stratification, mediation pathways)
\end{itemize}

\textbf{Best practice:} Report both minimax (conservative bound) and traditional (descriptive estimate) for transparency. The gap between them quantifies transportability concern and informs how conservatively to plan.
```

**Rationale:**
- Clearly positions minimax against traditional methods
- Shows empirical evidence of coverage under violations (95% vs 70-75%)
- Emphasizes complementarity (different questions)
- Provides practical guidance on when to use each
- Explains the "transportability gap" as diagnostic

---

### Change 5: Add Discussion Section (New Section 6)

**Location:** After Section 5 (Simulation study), before Section 7 (Theoretical properties, which becomes Section 7)

**New section:**

```latex
\section{Discussion}

\subsection{Position in the literature}

Parast et al. (2024) identified "limited work on transportability of surrogate knowledge from one study to another" as a key gap in surrogate evaluation methodology. Our minimax framework directly addresses this gap by providing the first formal approach to \textbf{evaluate} (rather than assume) transportability of surrogate relationships.

Existing methods—proportion of treatment effect (PTE), within-study correlation, principal stratification, causal mediation—provide valuable tools for \emph{describing} surrogate relationships in the current study. However, they all assume that these relationships will hold in future studies with different populations. When this assumption is violated (as shown in Section 5.3, Scenario B), traditional methods exhibit 20-25 percentage point undercoverage, potentially leading to overconfident conclusions about surrogate quality.

The minimax approach provides \textbf{conservative bounds} that maintain nominal coverage even under transportability violations. This is achieved by computing worst-case performance over a class of plausible distributional shifts (parameterized by λ and the innovation class M). The resulting bounds are appropriate for prospective decision-making where future populations are uncertain and conservative guarantees are needed.

Importantly, minimax and traditional methods are \textbf{complementary, not competing}. They answer different questions:
\begin{itemize}
    \item \textbf{Minimax:} "What is the worst-case surrogate performance in future studies within TV distance λ?" (prospective)
    \item \textbf{Traditional:} "What is the surrogate performance in the current study?" (retrospective)
\end{itemize}

The gap between minimax bounds and traditional estimates provides diagnostic information: a narrow gap suggests low transportability concern (future likely resembles current), while a wide gap flags high concern (conservative planning warranted). For transparency, we recommend reporting both.

\subsection{Computational innovation enables practical implementation}

A potential limitation of minimax inference is computational cost: computing worst-case bounds over many innovation distributions and discretization schemes can be expensive. With correlation-based functionals, a single λ value may require 30-60 seconds for comprehensive grid search over M (Section 3.3).

We address this through the \textbf{concordance functional with closed-form DRO solutions} (Section 3.7). By recognizing that concordance E[τ_S·τ_Y] is linear in the type distribution, we apply exact solutions from the distributional robustness optimization literature:
\begin{itemize}
    \item \textbf{TV-ball:} Closed-form φ* = E_P0[h] - λ·||h||∞ (Ben-Tal et al. 2013)
    \item \textbf{Wasserstein:} 1-parameter dual optimization (Esfahani & Kuhn 2018)
\end{itemize}

These solutions provide 9-487× speedup compared to sampling-based correlation inference (4ms vs 38-1963ms), reducing the computational cost of comprehensive sensitivity analyses from hours to seconds. This enables:
\begin{itemize}
    \item \textbf{Real-time inference} for decision support (sub-second response)
    \item \textbf{Large-scale simulations} (1000s of analyses in seconds, not hours)
    \item \textbf{Interactive sensitivity tools} (explore λ interactively)
    \item \textbf{Routine use in practice} (low computational barrier)
\end{itemize}

The trade-off is that closed-form solutions provide only the \textbf{worst-case bound} (minimum), not the full distribution of φ(Q) over Q ∈ B_λ(P_0). Sampling-based approaches provide richer distributional information (mean, median, quantiles, variance) useful for risk profiling. A hybrid approach—screening with closed-form concordance, then detailed distributional analysis at critical λ values with sampling-based correlation—balances efficiency and depth.

For most applications, the worst-case bound is sufficient for decision-making. When risk profiling is needed (e.g., portfolio management across studies with different risk tolerance), the full distribution adds value. Software implementing both options is available in the R package \texttt{surrogateTransportability}.

\subsection{Practical recommendations}

Based on the theoretical development, simulation studies, and methods comparison, we offer the following guidance:

\subsubsection{Workflow for surrogate evaluation}

\textbf{Step 1: Quick assessment with minimax-concordance}
\begin{itemize}
    \item Compute φ*(λ) for λ ∈ {0.1, 0.15, ..., 0.5} using closed-form solution
    \item Time: <50ms for entire sensitivity analysis
    \item Interpretation: Worst-case surrogate quality at each λ
\end{itemize}

\textbf{Step 2: Identify critical λ values}
\begin{itemize}
    \item Find λ_crit = sup{λ : φ*(λ) ≥ threshold}
    \item Interpretation: Maximum tolerable distributional shift
\end{itemize}

\textbf{Step 3: Detailed analysis (if needed)}
\begin{itemize}
    \item At critical λ, compute φ*(λ) with correlation functional for clinical interpretability
    \item Optional: Full distributional analysis if risk profiling needed
    \item Time: ~40ms per λ value
\end{itemize}

\textbf{Step 4: Compare to traditional methods}
\begin{itemize}
    \item Compute PTE, within-study correlation, mediation effects
    \item Report gap: minimax - traditional
    \item Interpretation: Gap size quantifies transportability concern
\end{itemize}

\textbf{Step 5: Decision and reporting}
\begin{itemize}
    \item Use minimax for conservative planning (prospective decisions)
    \item Report traditional for descriptive context (current study performance)
    \item Document λ_crit and transportability gap for transparency
\end{itemize}

\subsubsection{Choosing λ (perturbation level)}

The choice of λ encodes \emph{how different} a future study might be:
\begin{itemize}
    \item λ = 0.1: "Future studies very similar to current" (small shift)
    \item λ = 0.3: "Moderate differences expected" (recommended default)
    \item λ = 0.5: "Substantial differences possible" (conservative)
\end{itemize}

We recommend sensitivity analysis across λ ∈ [0.1, 0.5] rather than fixing a single value. The pattern φ*(λ) as λ increases reveals how robust surrogate quality is to distributional shifts.

\subsubsection{Interpreting results}

\textbf{If φ*(λ) ≥ threshold for large λ:}
\begin{itemize}
    \item Surrogate is robust to substantial distributional shifts
    \item Transportability concern is low
    \item Can proceed with confidence for future studies
\end{itemize}

\textbf{If φ*(λ) < threshold even for small λ:}
\begin{itemize}
    \item Surrogate quality degrades quickly with any shift
    \item Transportability concern is high
    \item Consider alternative surrogates or require closer similarity
\end{itemize}

\textbf{If φ*(λ) crosses threshold at intermediate λ:}
\begin{itemize}
    \item λ_crit defines "safe" region for surrogate use
    \item Future studies must be within TV distance λ_crit
    \item May require enrichment strategies or covariate matching
\end{itemize}

\textbf{If minimax << traditional (large gap):}
\begin{itemize}
    \item High sensitivity to population differences
    \item Traditional methods may be overoptimistic
    \item Use minimax for conservative planning
\end{itemize}

\subsection{Limitations and extensions}

\subsubsection{Current limitations}

\textbf{Finite support assumption.}
The implementation requires discretizing continuous covariates into J types. While Section 2 justifies this as approximating the continuous treatment effect distribution τ(X), the approximation error depends on J and the discretization scheme. The RF-ensemble approach (Section 7) mitigates this by using multiple schemes, but a direct continuous-space extension would be preferable. Recent work on continuous DRO (Kuhn et al. 2019) suggests this may be feasible.

\textbf{Treatment effect heterogeneity.}
The perturbation model captures shifts in the distribution of treatment effects via reweighting types. More complex violations—such as changes in effect moderation structure or unmeasured confounding—are not directly modeled. Extensions to richer structural assumptions (e.g., sensitivity analysis frameworks) could address these.

\textbf{Single outcome and surrogate.}
The current framework handles one surrogate for one outcome. Multiple surrogates (composite endpoints) and multiple outcomes (co-primary endpoints) require joint distributional modeling, increasing dimensionality. Tensor-based perturbations or factor models may extend the approach.

\subsubsection{Promising extensions}

\textbf{Meta-analytic integration.}
When multiple studies are available, the minimax framework can integrate heterogeneous evidence by treating each study as a draw from F and estimating functionals φ(F) via empirical distributions. This bridges single-study minimax and classical meta-analytic validation.

\textbf{Bayesian implementation.}
The perturbation model admits a natural Bayesian interpretation: place a prior on the innovation distribution μ and compute posterior distributions on φ(F_λ). This would provide full uncertainty quantification and enable decision-theoretic optimal stopping rules.

\textbf{Real-time monitoring.}
With 4ms inference time via concordance, minimax bounds can be recomputed continuously as data accrues in an ongoing trial. This enables adaptive decision-making: "Is the surrogate validated well enough to stop the trial early?" or "Should we enrich for subgroups with strong surrogate-outcome concordance?"

\textbf{Interactive web tools.}
The computational efficiency enables interactive visualization of φ*(λ) and distributional shifts. Users could upload data, select discretization schemes, adjust λ interactively, and explore worst-case scenarios visually. This could democratize minimax inference beyond specialist statisticians.

\textbf{Extensions to longitudinal and time-to-event outcomes.}
The current framework handles continuous, binary, or count outcomes measured at a single time. Extensions to survival analysis (time-to-event surrogates) or longitudinal trajectories (growth curve surrogates) would broaden applicability. The type-level abstraction (discretizing into J regimes) may generalize naturally.

\subsection{Conclusion}

Evaluating whether surrogate knowledge transports across studies is fundamental to surrogate marker validation but has received limited methodological attention. This paper provides the first formal framework to compute worst-case surrogate performance bounds under plausible distributional shifts, filling the gap identified by Parast et al. (2024).

Two innovations make this practical: (1) the random probability measure framework with minimax inference eliminates dependence on untestable innovation distribution assumptions, providing conservative guarantees appropriate for prospective decision-making; (2) the concordance functional with closed-form DRO solutions reduces computational cost by two orders of magnitude, enabling real-time inference and comprehensive sensitivity analyses.

The approach complements rather than replaces traditional surrogate validation methods. Traditional methods (PTE, within-study correlation, mediation) describe surrogate relationships in the current study; minimax evaluates whether those relationships will hold in future studies. Together, they provide a complete picture: descriptive performance (current study) and conservative bounds (future studies), with the gap between them diagnosing transportability risk.

We recommend routine use of minimax inference for prospective surrogate validation, particularly when future populations are uncertain, conservative planning is prudent, or regulatory decisions depend on surrogate endpoints. The computational efficiency of the concordance functional makes this practical even for large-scale applications.
```

**Rationale:**
- Positions contribution clearly (addresses Parast 2024 gap)
- Emphasizes complementarity with traditional methods
- Highlights computational innovation and what it enables
- Provides detailed practical guidance
- Documents limitations and extensions honestly
- Ends with strong conclusion emphasizing the two pillars (scientific + computational)

---

## Summary of Recommended Changes

### High Priority (Essential for Resubmission)

1. **Introduction: Rewrite opening paragraph** (Change 1)
   - Lead with transportability gap (Parast 2024)
   - Emphasize evaluate vs assume distinction
   - Position as complementary, not competing

2. **Introduction: Update Table 1** (Change 1)
   - Add "Transportability" column (Evaluated vs Assumed)
   - Make key distinction immediately visible

3. **Section 3: Reframe minimax opening** (Change 2)
   - Lead with scientific motivation (prospective decisions)
   - Frame μ-elimination as means, not end

4. **Section 5: Add subsection 5.3** (Change 4)
   - Empirical comparison to traditional methods
   - Coverage under violations: 95% vs 70-75%
   - Performance benchmarks table
   - Complementarity guidance

5. **Add Discussion section** (Change 5)
   - Position in literature (Parast gap)
   - Complementarity with traditional methods
   - Practical recommendations (workflow, interpretation)
   - Limitations and extensions

### Medium Priority (Strongly Recommended)

6. **Section 3: Add subsection 3.7** (Change 3)
   - Concordance functional mathematical development
   - Closed-form DRO solutions (Ben-Tal, Esfahani & Kuhn)
   - 9-487× speedup documentation
   - Trade-off analysis (speed vs distributional info)
   - Performance comparison table
   - When to use concordance vs correlation

7. **Abstract: Add to paper** (not shown above, needs writing)
   - 150-200 words summarizing the two pillars
   - Emphasize evaluate vs assume + computational innovation

### Lower Priority (Can defer if space-constrained)

8. **Section 2: Add paragraph on treatment effect heterogeneity**
   - Clarifies types as discretization of τ(X)
   - Justifies concordance as natural functional
   - Already partially present but could be strengthened

9. **Figures throughout:**
   - Figure 1: Coverage by method and scenario (bar chart)
   - Figure 2: Computation time comparison (log scale)
   - Figure 3: Example φ*(λ) sensitivity curve
   - Figure 4: Transportability gap illustration

10. **Supplementary materials:**
    - Table S1: Detailed methods comparison (all 6 methods)
    - Table S2: Full benchmark results (multiple n, J)
    - Figure S1: Distributional information from sampling
    - Code repository and reproducibility

---

## Manuscript Length Considerations

**Current length:** ~30 pages (estimated from 6 sections × 5 pages average)

**Recommended additions:**
- Section 3.7 (Computational): +3 pages
- Section 5.3 (Comparison): +3-4 pages
- Section 6 (Discussion): +4-5 pages
- Introduction revisions: +0.5 pages
- **Total added:** ~11-13 pages

**Resulting length:** ~41-43 pages

**If target journal has length limits:**
- Move Section 3.7 to Supplement (keep 1-paragraph summary in main text)
- Move detailed Table Y (computational performance) to Supplement
- Shorten Section 6.4 (Limitations) by moving some to Supplement
- **Reduced length:** ~35-37 pages (main text)

---

## Key Messages for Cover Letter / Response to Reviewers

When submitting or revising, emphasize:

1. **Fills identified gap:** Parast et al. (2024) called for work on transportability; we provide first formal framework

2. **Novel distinction:** Only method that evaluates (not assumes) transportability—shown empirically with coverage under violations

3. **Computational breakthrough:** Closed-form DRO solutions enable practical implementation (9-487× speedup)

4. **Complementary approach:** Not competing with traditional methods—different questions require different tools

5. **Practical impact:** Enables applications previously infeasible (real-time monitoring, large-scale sensitivity)

---

## Implementation Timeline

**Phase 1 (High Priority): 2-3 days**
- Day 1: Introduction revisions + Table 1 update + Section 3 reframe
- Day 2: Section 5.3 (methods comparison) + figures
- Day 3: Section 6 (Discussion) + abstract

**Phase 2 (Medium Priority): 1-2 days**
- Day 4: Section 3.7 (computational innovation)
- Day 5: Figures, tables, final polishing

**Phase 3 (Lower Priority): 1 day**
- Day 6: Supplementary materials, code repository

**Total:** 4-6 days for complete restructuring

---

## Bottom Line

The current manuscript undersells the contribution by framing it as "a method with different assumptions" rather than **"the only method that evaluates transportability"** with **computational efficiency that makes it practical**.

The restructuring emphasizes:
1. **Scientific contribution:** Evaluate vs assume transportability (fills Parast 2024 gap)
2. **Computational innovation:** Closed-form DRO enabling real-time inference
3. **Complementarity:** Different questions, not competing methods
4. **Practical guidance:** When and how to use minimax vs traditional

This framing positions the paper for high-impact publication in top methods journals (Biometrics, Biostatistics, JASA) by highlighting both theoretical rigor and practical applicability.

**Recommendation:** Prioritize High Priority changes (Introduction, Section 5.3, Discussion) for immediate revision. Add Medium Priority (Section 3.7 on concordance) if space permits or in Supplement. The combination of these changes transforms the paper from "interesting technical development" to "foundational contribution solving an identified gap."
