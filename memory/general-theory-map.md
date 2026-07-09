---
name: general-theory-map
description: The most-general theory of the method (estimand, layered reduction, assumptions A1-A8, regularity boundary) — the map to build from
metadata:
  type: project
---

`explorations/small_n/GENERAL_THEORY.md` (branch `main`, 2026-07-09) maps the most general form of the local-geometric surrogate-transportability method, before further building. Builds on [[small-n-cate-exploration]] and extends the committed proof (`inst/paper/proof_asymptotic_normality.tex`) as its finite-support special case.

**General estimand:** Θ = Ψ(E_μ[φ_j(Δ(Q))]) — any smooth Ψ of μ-moments of study-level effects Δ(Q) = E_{P₀}[w(X)τ(X)]. Correlation/R²/MSPE/concordance are instances.

**Layered reduction (the organizing insight):** P₀ →(L1 estimate CATEs β)→ β →(L2 reweight)→ Δ(Q) →(L3 aggregate over μ)→ moments →(L4 smooth Ψ)→ Θ. L2∘L3 makes the key moments **quadratic/bilinear functionals of the CATEs against the reweighting-covariance kernel C(x,x')=Cov_μ(w(x),w(x'))**: Var_μ(Δ_S)=∬C τ_S τ_S dP₀², Cov_μ=∬C τ_S τ_Y. Discrete: C→Σ, τ'Στ. Same object discrete & continuous ⇒ ALL the difficulty is one classical problem: estimating quadratic functionals of a regression.

**Assumptions A1–A8** (ledger with what each buys / how to relax): A1 identification, A2 CATE asymptotic-linearity (load-bearing; only its IF is needed downstream), A3 Q≪P₀ + bounded weights, A4 convex geometry + geometric-ergodic hit-and-run, **A5 quadratic/bilinear-functional √n-estimability (THE boundary)**, A6 cross-fit nuisance rates, A7 smooth non-degenerate Ψ, A8 n & M regime.

**A5 regularity boundary (VERIFIED vs literature 2026-07-09):** for the COVARIANCE of two different CATEs, √n-estimability requires the **bilinear sum-of-smoothness condition s_S + s_Y > d/2** (d=dim X), reducing to s > d/4 under equal smoothness (a smoother surrogate CATE compensates for a rougher outcome CATE). Below it: minimax rate n^{−4s/(4s+d)}, no √n normality (higher-order IFs attain the rate but don't restore √n). A smooth kernel C relaxes it (so the condition is conservative here). Refs: Bickel-Ritov 1988, Birgé-Massart 1995, Robins et al. 2008/2017, McClean/Kennedy et al. 2024, Chernozhukov et al. 2018.

**General limit theorem (target, not yet formally proven):** √n(Θ̂−Θ)=𝔾_n[ψ_Θ] + (n/M)^{1/2}𝒵_M + o_P(1); ψ_Θ = ∇Ψ · EIF-of-moment-vector, propagating IF_τ through the one-step derivative of each quadratic functional (=2∫C(x,·)τ dP₀). Joint (n=o(M)) vs conditional-on-μ̂_M statements. Cross-outcome covariance enters because IF_{τ_S},IF_{τ_Y} share units.

**Next deliverable (build phase):** formal Proposition with the EIF derived explicitly (route: EIF of a quadratic functional of a regression → chain through ∇Ψ) + precise A5 threshold statement; this becomes the paper's general supplement, current proof = its special case. Verified building blocks in hand: analytic ∇Ψ (07), exact discrete IF_τ, tr(ΣV) = discrete instance of L3 debiasing.
