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
- **A3 (Absolute continuity + bounded weights).** Q ≪ P₀ and
  `sup_x w(x) ≤ C < ∞` μ-a.s. *Buys:* Δ(Q) is a bounded linear functional of β;
  no extrapolation beyond supp(P₀); AIPW remainder uniform over Q. *Dial:*
  relaxing Q ≪ P₀ (extrapolation) requires a model for β off-support — a strictly
  stronger, different theory. This is the paper's stated boundary.

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
assumption** the finite-support proof hides (there it is automatic).

---

## 4. General limit theorem (target statement)

> **Proposition (general).** Under A1–A8, with debiased (one-step, cross-fit)
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
for discrete or smooth-enough continuous X** — the binding constraint is A5, the
√n-estimability of the quadratic/bilinear functionals of the CATEs, which for
continuous X requires the combined CATE smoothness `s_S + s_Y > dim(X)/2` (reducing
to `s > dim(X)/4` when both CATEs are equally smooth); below that boundary only
slower minimax rates are attainable and inference must be reported accordingly.

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
