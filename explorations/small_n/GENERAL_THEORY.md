# General theory map for local-geometric surrogate transportability

**Status:** theory map (2026-07-09). Scope only — states the most general estimand,
the layered reduction, the assumption ledger (what each assumption buys and where
it is used), the general limit theorem, and the regularity boundary. Extends (does
not contradict) `inst/paper/proof_asymptotic_normality.tex`; where this map is
more general, the differences are flagged. No implementation.

Goal: identify the *most general* setting in which the method has a well-defined
estimand and √n asymptotically-normal inference, and the *minimal* assumptions
that get us there — so future work (continuous X, other functionals, other
geometries) knows exactly which assumption it is relaxing.

---

## 1. Objects and the general estimand

Observe one study: `O = (X, A, S, Y) ~ P₀`, `A ∈ {0,1}`, `X ∈ 𝒳` (discrete OR
continuous/multivariate). Per-unit effect functions (the CATEs)
```
β(x) = (τ_S(x), τ_Y(x)) = ( E[S(1)−S(0) | X=x],  E[Y(1)−Y(0) | X=x] ).
```

A **future study** is a distribution Q ≪ P₀ with density ratio (reweighting)
`w = dQ/dP₀`; its study-level effects are the linear functionals
```
Δ(Q) = (Δ_S(Q), Δ_Y(Q)),   Δ_S(Q) = E_{P₀}[ w(X) τ_S(X) ]   (and similarly Δ_Y).
```

A **geometry** is a probability measure μ over reweightings w, supported on a
local set U(P₀, λ; d) = {Q : d(Q,P₀) ≤ λ}. **General estimand:**
```
Θ(P₀, λ) = Ψ( m₁, …, m_K ),   m_j = E_{Q~μ}[ φ_j(Δ(Q)) ],
```
Ψ : ℝ^K → ℝ smooth, each φ_j a fixed polynomial/moment of the pair Δ(Q). This is
the paper's general form (PAPER_OUTLINE §2.2). Correlation, R², MSPE, concordance
are instances.

---

## 2. The layered reduction (the organizing structure)

Θ decomposes into four composable layers. The generality of the method is exactly
the generality achievable at each layer; the assumptions attach layer by layer.

```
   P₀  ──(L1: CATE estimation)──▶  β(·) = (τ_S, τ_Y)
       ──(L2: reweighting)──────▶  Δ(Q) = linear functional of β, per Q
       ──(L3: μ-aggregation)────▶  m_j = E_μ[φ_j(Δ(Q))]  ← QUADRATIC/POLYNOMIAL functionals of β
       ──(L4: outer map)────────▶  Θ = Ψ(m)              ← smooth scalar map
```

**Key structural fact (the unifying insight).** For the moments that matter
(means, variances, covariance of Δ across μ), L2∘L3 makes each `m_j` a
**quadratic (more generally polynomial) functional of β against a fixed kernel**:
```
E_μ[Δ_S(Q)]        = ∫ ā(x) τ_S(x) dP₀(x),                    ā(x)=E_μ[w(x)]      (LINEAR)
Cov_μ(Δ_S,Δ_Y)     = ∬ C(x,x') τ_S(x) τ_Y(x') dP₀(x)dP₀(x'),  C=Cov_μ(w(x),w(x')) (QUADRATIC)
Var_μ(Δ_S)         = ∬ C(x,x') τ_S(x) τ_S(x') dP₀dP₀                                (QUADRATIC)
```
Discrete X: `C(x,x') → Σ = Cov_μ(q)` and the integrals are `τᵀΣτ`. Continuous X:
`C` is the reweighting-covariance kernel of the geometry. **Same object, both
cases.** So the ENTIRE small-n / continuous-X difficulty concentrates in one
classical problem: **estimating quadratic functionals of a regression function β**.
Everything else (L1 identification, L4 delta method) is standard.

---

## 3. Assumption ledger — what each buys, where used

Grouped by layer. For each: statement, what it enables, and how it could be
relaxed (the "generalization dial").

### L0 — Meaning of the estimand (the transportability assumption)
- **A0 (Conditional-effect transportability given X).** All cross-study variation
  in treatment effects is *compositional in the measured covariates X*: future
  studies may differ in the marginal distribution of X but share P₀'s conditional
  law of potential outcomes given X. Equivalently, the reweighting `w = dQ/dP₀`
  depends on X only, so `τ_S(x), τ_Y(x)` are frozen at their P₀ values in every Q.
  *Buys:* the entire L2 construction `Δ_S(Q) = E_{P₀}[w(X)τ_S(X)]` — i.e. that the
  sampled study effects are a functional of X-cell effects (this is what makes the
  method "sample Q, reweight, correlate" without ever modelling within-X
  heterogeneity). *Status:* this is a **substantive causal assumption**, of the
  Dahabreh–Hernán "effects transport conditional on X" class — NOT a
  support/computational condition. It was previously conflated with A3 (`Q ≪ P₀`);
  they are distinct: A3 is support, A0 is the causal content.
  *Two readings:*
  - **Definitional (assumption-free):** the estimand simply IS the correlation
    over the class of X-compositional future studies. Then A0 is not an assumption,
    just a *scope statement* — be clear the futures considered differ in who-is-in-
    them (by X), not in the X→effect relationship.
  - **Interpretive (needs A0):** to read the estimand as "does the surrogate
    transport to REAL future studies," A0 must hold — real futures differ from P₀
    only compositionally in X.
  *Dial / relaxation:* A0 **cannot be dropped for a point estimate from a single
  study** — it is an identification barrier (to reweight two units with the same X
  differently, `w` must depend on an unobserved modifier U, which cannot be keyed
  to from one study; weighting on A breaks randomization, weighting on the factual
  outcome selects on the outcome). It CAN be relaxed to an **interval** via the
  observation-level construction (§3bis).

### L1 — Identification & estimation of the CATEs β
- **A1 (Identification).** SUTVA, consistency, and either randomization
  (`A ⟂ (S(a),Y(a)) | X`, known e(x)) or unconfoundedness with overlap
  `η ≤ e(x) ≤ 1−η`. *Buys:* β(x) is a functional of the observed-data law.
  *Dial:* IV / sensitivity models would replace this (changes β's identification,
  not the L2–L4 structure).
- **A2 (CATE estimability / asymptotic linearity).** Each τ̂ admits
  `τ̂(x) − τ(x) = 𝔾_n IF_τ(·;x) + R(x)` with a mean-zero influence function IF_τ
  and remainder controlled (see A6). *Buys:* everything downstream — L3 debiasing
  and L4 delta method both consume IF_τ. *Dial:* this is THE load-bearing
  regularity condition; discrete cell-means satisfy it exactly, AIPW/DR-learners
  under rate conditions, forests only under Wager–Athey-type conditions.

### L2 — Reweighting (Q ≪ P₀)
- **A3 (Absolute continuity + bounded weights).** Q ≪ P₀ (on the X-marginal) and
  `sup_x w(x) ≤ C < ∞` μ-a.s. *Buys:* Δ(Q) is a bounded linear functional of β;
  no extrapolation beyond supp(P₀); AIPW remainder uniform over Q. *Distinct from
  A0:* A3 is a support/computational condition (no new X values); A0 is the causal
  claim that effects are frozen within X. Both are needed and they are not the
  same. *Dial:* relaxing Q ≪ P₀ (extrapolation to new X) requires a model for β
  off-support — a strictly stronger, different theory. This is the paper's stated
  boundary on the X-support side; A0 is the boundary on the within-X side.

### L3 — μ-aggregation over the geometry (the quadratic-functional layer)
- **A4 (Geometry regularity).** U(P₀,λ;d) is a convex body (TV, χ², L₂ balls);
  μ = uniform, sampled by a geometrically ergodic hit-and-run chain; the kernel
  `C(x,x') = Cov_μ(w(x),w(x'))` exists and is bounded. *Buys:* the moments m_j are
  well-defined bounded quadratic functionals; MCMC-CLT for the Σ_q / C estimate.
  *Dial:* non-uniform μ, other divergences (KL, Wasserstein) change C but not the
  quadratic structure.
- **A5 (Quadratic/bilinear-functional estimability — THE regularity boundary).**
  The functionals `∬ C(x,x') τ_a(x) τ_b(x') dP₀²` (a,b ∈ {S,Y}) admit √n-consistent
  (debiased) estimation. For discrete/finite X this is automatic. For continuous X
  it is governed by the **quadratic-functional "elbow"** (VERIFIED against the
  literature, 2026-07-09):
  - **Variance terms** (a=b, pure quadratic `∬C τ_a τ_a`): √n-estimable iff τ_a has
    Hölder/Sobolev smoothness `s_a > d/4` (`d = dim X`). At the elbow `s_a = d/4`
    the rate hits √n; below it the minimax rate is `n^{−4s_a/(4s_a+d)}` (slower
    than √n) and **no √n-normal estimator exists** (Bickel & Ritov 1988 for ∫f²;
    Birgé & Massart 1995; Robins, Li, Tchetgen Tchetgen & van der Vaart 2008).
  - **Covariance term** (a=S, b=Y, BILINEAR in two DIFFERENT CATEs — our actual
    object): the correct condition is the **sum-of-smoothness** rule
    `s_S + s_Y > d/2`, which reduces to `s > d/4` only when both CATEs share
    smoothness `s`. A smoother surrogate CATE can compensate for a rougher outcome
    CATE (McClean, Branson, Kennedy et al. 2022/2024; Robins et al. 2016; Kennedy,
    Balakrishnan, Robins & Wasserman, Ann. Statist. 2024).
  - **Kernel caveat:** the elbow is the boundary for the identity/Dirac kernel. A
    genuinely smooth/bounded reweighting kernel `C` only *relaxes* the requirement
    (absorbs smoothness), so `s_S + s_Y > d/2` is CONSERVATIVE here (our `C` is
    bounded under A3–A4). Higher-order influence functions extend estimation below
    the elbow to the minimax rate but do NOT restore √n.

  **State A5 as `s_S + s_Y > d/2`.** *Dial:* not removable — a fact about the
  problem. Below the boundary, report the slower minimax rate / wider intervals
  honestly. Discrete X and smooth-enough continuous X are inside it.

### L4 — Outer smooth map Ψ and combination
- **A6 (Nuisance rates / cross-fitting).** Product/second-order remainders are
  `o_P(n^{-1/2})`: for AIPW, `‖ê−e‖·‖μ̂−μ‖ = o_P(n^{-1/2})` (e.g. each
  `o_P(n^{-1/4})`), with cross-fitting. *Buys:* first-order (one-step) debiasing of
  the L3 quadratic functionals removes plug-in bias to `o_P(n^{-1/2})`.
- **A7 (Functional smoothness + non-degeneracy of Ψ).** Ψ is continuously
  (Hadamard) differentiable at m with bounded gradient on the region where the
  L3 variances are bounded below: `Var_μ(Δ_S), Var_μ(Δ_Y) ≥ c₀ > 0`. *Buys:* the
  delta method; correlation's `1/√(ab)` factor is bounded. *Dial:* non-smooth Ψ
  (quantiles, max) needs a different (non-δ-method) treatment — flagged, not covered.
- **A8 (Sample-size / MCMC regime).** n → ∞; M = M(n). The joint error has an n
  part (rate √n) and an M part (rate √M). *Buys:* the combined limit (§4). The
  *unconditional* statement centered at Θ(μ) needs `n = o(M)`; otherwise the honest
  statement is conditional on μ̂_M (the paper's stance).

Minimality note: A1–A4, A6–A8 are essentially the canonical proof's assumptions
generalized off the finite simplex. **A5 is the genuinely new, general-case
assumption** the finite-support proof hides (there it is automatic). **A0 is the
substantive causal assumption** that makes the estimand a transportability claim.

---

## 3bis. Relaxing A0: the observation-level estimand as a partial-ID interval

A0 freezes effects within X. Relaxing it defines the **observation-level estimand**:
future studies may reweight the individual effect distribution `(τ_S(X,U),
τ_Y(X,U))`, not just the X-marginal. Verified findings
(`explorations/obs_level/`):

- **Well-defined and A0-consistent:** the observation-level correlation equals the
  X-level correlation exactly when A0 holds (no within-X effect heterogeneity), and
  is otherwise **more conservative** (less extreme). The X-level ↔ obs-level GAP
  measures exposure to unmeasured within-X heterogeneity — genuine signal, not a
  noise artifact. (The deprecated `observation_level_minimax` code did NOT deliver
  this — it reweighted by X-distance, so identical-X units got identical weights;
  it was X-level in disguise. A real obs-level construction must perturb U|X.)

- **Partial identification (the key result):** the obs-level correlation depends on
  the within-X effect moments `v_S(x)=Var(τ_S|x)`, `v_Y(x)=Var(τ_Y|x)`,
  `c_SY(x)=Cov(τ_S,τ_Y|x)`.
  - `v_S, v_Y` are **identified** from an RCT: `Var(S|A=1,x) − Var(S|A=0,x)` (and
    similarly Y). Verified.
  - `c_SY(x)` is **NOT identified** — it is the correlation of potential outcomes
    (τ_S and τ_Y effects are never jointly observed on one unit). The naive
    difference-of-covariances estimator is valid only if effects are independent of
    baselines within X, and breaks otherwise (stress test: error 0.05→0.56→1.21 as
    effect–baseline dependence grows). Classic PO-correlation non-identifiability.

- **⇒ A0-sensitivity interval.** Since `v_S, v_Y` are identified and `c_SY(x)` is
  bounded by Cauchy–Schwarz, `|c_SY(x)| ≤ √(v_S(x) v_Y(x))`, sweep `c_SY` over its
  feasible range and report `[ρ_obs_lo, ρ_obs_hi]`. This is a **data-powered
  sensitivity analysis for A0**: the bound width is constrained by the observed
  within-X spread, not a free dial. Reframes "report both X-level and obs-level" as
  **"report the X-level point estimate and its A0-sensitivity bounds."**

- **Where this sits in the layers:** the obs-level moments are again quadratic/
  bilinear functionals (now of the individual-effect distribution), so A5's
  estimability boundary applies to `v_S, v_Y` too; the extra content is only the
  unidentified `c_SY` sweep. So this relaxation is *additive* on top of the L1–L5
  machinery, not a separate theory.

*Open (build phase):* prototype the interval, check coverage of the true obs-level
correlation across scenarios, and whether cross-cell structure tightens the CS
bound. (`explorations/obs_level/FINDINGS.md`.)

---

## 4. General limit theorem (target statement)

> **Proposition (general).** Under A0 (so the estimand is the X-compositional
> transportability functional) and A1–A8, with debiased (one-step, cross-fit)
> estimators of the L3 quadratic functionals and Θ̂ = Ψ(m̂),
> ```
> √n ( Θ̂ − Θ(P₀,λ) )  =  𝔾_n[ ψ_Θ ]  +  (n/M)^{1/2} 𝒵_M  +  o_P(1),
> ```
> where ψ_Θ = ∇Ψ(m)ᵀ · (EIF of the moment vector m) is the efficient influence
> function, `𝔾_n[ψ_Θ] →_d N(0, Var ψ_Θ)`, and `𝒵_M = O_P(1)` is the MCMC term
> (Markov-chain CLT under A4). Hence:
> - **Joint / unconditional (A8 with n=o(M)):** `√n(Θ̂−Θ) →_d N(0, σ²)`, `σ²=Var ψ_Θ`.
> - **Conditional on μ̂_M (any M):** `√n(Θ̂−Θ(μ̂_M)) →_d N(0, σ²(μ̂_M))`, with an
>   O_P(M^{-1/2}) bias to Θ(μ).

The EIF ψ_Θ propagates the CATE influence function IF_τ through: (L4) ∇Ψ, (L3) the
derivative of each quadratic functional w.r.t. β (= `2∫C(x,·)τ(·)dP₀`, the
"one-step" direction), giving a closed-form ψ_Θ in terms of IF_τ and the kernel C.
The **cross-outcome covariance** enters because IF_{τ_S} and IF_{τ_Y} share units.

Building blocks already in hand: analytic ∇Ψ for correlation (verified, `07`),
exact IF_τ for the saturated/discrete case (verified), and the tr(ΣV) = discrete
instance of the L3 debiasing term (verified, `CONTINUOUS_CASE.md`).

---

## 5. Special cases recovered (sanity checks the general theory must satisfy)

1. **Discrete X, correlation, reweighting estimator (current canonical).** C→Σ,
   quadratic functionals = τᵀΣτ, A5 automatic, IF_τ = per-cell AIPW score, ψ_Θ =
   the two-stage IF of the existing proof. Debiasing term tr(ΣV). ✔ matches proof.
2. **Discrete X, general Ψ (R², MSPE, concordance).** Only ∇Ψ changes; same ψ_Θ
   machinery. ✔ matches PAPER_OUTLINE general estimand.
3. **Continuous X, smooth β (`s_S + s_Y > d/2`).** A5 holds; the one-step debiased
   quadratic/bilinear-functional estimator gives √n-normal Θ̂; CATE learner supplies
   IF_τ. ← the target continuous-case result.
4. **Continuous X, rough β (`s_S + s_Y ≤ d/2`).** A5 FAILS; Θ̂ has a slower-than-√n
   minimax rate (higher-order IFs attain it but do not restore √n); no √n
   normality. ← the honest limit; report slower rate / wider intervals.

---

## 6. The regularity boundary in one sentence

The method has √n, asymptotically-normal, efficient inference for **any smooth
functional Ψ of the study-effect distribution, under any convex local geometry,
for discrete or smooth-enough continuous X** — subject to two boundaries:
- **A0 (causal / within-X):** the point estimand is a transportability claim only
  under conditional-effect transportability given X (effects frozen within X).
  This is an identification barrier, not an estimation one; relaxing it yields the
  observation-level partial-ID interval (§3bis), not a different point estimate.
- **A5 (statistical / smoothness):** √n-estimability of the quadratic/bilinear
  functionals of the CATEs requires combined smoothness `s_S + s_Y > dim(X)/2`
  (→ `s > dim(X)/4` under equal smoothness); below it only slower minimax rates.

A0 governs *what the estimand means*; A5 governs *how well we can estimate it*.
Both must be stated; neither is removable, but each has an honest fallback
(A0 → sensitivity bounds; A5 → report the slower rate).

---

## 7. What this map settles for future work

- **Disattenuation is not an ad-hoc fix** — it is the L3 one-step debiasing of a
  quadratic functional; the discrete tr(ΣV) and the continuous functional
  correction are the same object.
- **CATE estimation matters only at L1**, and only its *influence function* is
  needed downstream — clarifying exactly what a pluggable learner must expose.
- **The next theory deliverable** is the formal Proposition of §4 with the EIF
  derived explicitly (route: EIF of a quadratic functional of a regression, then
  chain through ∇Ψ), plus verification of A5's smoothness threshold. That is the
  general result the paper's supplement should carry; the current proof is its
  finite-support special case.

Open items feeding the formal write-up: explicit EIF algebra for the quadratic-
functional layer; the exact A5 threshold statement + citation to the quadratic-
functional minimax literature; whether one-step suffices or TMLE-iteration is
needed for the ratio Ψ (expected: one-step + δ-method suffices under A7).

---

## 8. Key references for A5 (verified 2026-07-09)

Quadratic-functional elbow (s = d/4) and slow rate n^{−4s/(4s+d)}:
- Bickel, P. J. & Ritov, Y. (1988). Estimating integrated squared density
  derivatives: sharp best order of convergence estimates. *Sankhyā A* 50(3),
  381–393. [d=1 elbow at 1/4, verified verbatim]
- Birgé, L. & Massart, P. (1995). Estimation of integral functionals of a density.
  *Ann. Statist.* 23(1), 11–29.
- Robins, Li, Tchetgen Tchetgen & van der Vaart (2008). Higher order influence
  functions and minimax estimation of nonlinear functionals. *IMS Collections* 2,
  335–421.
- Robins, Li, Mukherjee, Tchetgen Tchetgen & van der Vaart (2017). Minimax
  estimation of a functional on a structured high-dimensional model. *Ann.
  Statist.* 45(5), 1951–1987.

Bilinear sum-of-smoothness condition (s_S + s_Y > d/2) and modern causal/CATE case:
- McClean, Branson, Kennedy et al. (2022/2024); McClean, Balakrishnan, Kennedy &
  Wasserman (arXiv:2403.15175) — DR estimator √n-normal above elbow; slow minimax
  below.
- Kennedy, Balakrishnan, Robins & Wasserman (2024). *Ann. Statist.*
  (DOI 10.1214/24-AOS2369) — "elbow phenomenon" for heterogeneous causal effects.
- Chernozhukov et al. (2018). Double/debiased ML. *Econometrics J.* 21(1), C1–C68
  — first-order orthogonality/cross-fitting (the o_p(n^{-1/4}) product rule, A6).

Note: a few exact page ranges (Fan 1991; Robins et al. 2017) are standard-citation
values, cross-checked against confirmed volume/DOI metadata but not re-quoted
verbatim this session — glance at the PDFs before these go to print.
