---
name: small-n-cate-exploration
description: Small-n correlation bias is a quadratic-functional (measurement-error) problem, NOT a CATE-estimation problem; continuous-X scoped
metadata:
  type: project
---

Exploration in `explorations/small_n/` (branch `main`) on the deferred small-n robustness work (see [[realignment-complete]]).

**Central conclusion (after several reframes with the user):** the small-n bias in Θ̂ is **O(1/n) attenuation of the correlation FUNCTIONAL**, NOT a CATE-estimation problem. For DISCRETE X, the reweighting estimator already IS the per-cell CATE plug-in — "better CATE estimation" was a distraction there. Confirmed by an n×M factorial: bias tracks n, not M (n:500→4000 cut dgp1 bias −0.28→−0.09; M barely moved it). Reweighted ATEs Δ̂(Q) are ~unbiased; the bias comes from correlating noisy estimates (denominator quadratic forms inflate by tr(ΣV)=O(1/n)).

**Unifying theory (`explorations/small_n/CONTINUOUS_CASE.md`):** Var_μ(Δ_S), Cov_μ, Θ are **quadratic functionals of τ**. Small-n bias = plug-in bias of quadratic functionals, with a known first-order (one-step/debiased) correction. VERIFIED: subtracting tr(ΣV̂) de-biases τ'Στ (bias +0.0008→−0.0003); full correction fixed dgp2 (bias +0.14→−0.04 at n=500). Discrete disattenuation = special case; **continuous X = same correction + functional bias term + cross-fitting**, reusing the paper's semiparametric machinery (Neyman orthogonality, cross-fitting). This is the chosen framing for the continuous extension (scoped, not built).

**Continuous X is structurally different:** τ(x) must be estimated as a function (CATE genuinely needed there); geometry is infinite-dim (discretize vs reweighting-function ball — open); noise and regularization bias entangle (naive tr(ΣV) doesn't directly transfer).

**Status of artifacts:**
- Pluggable CATE interface (cate_estimator, tv_ball_correlation_cate, se="if" IF-SE) — built + tested on branch `feature/pluggable-cate`, then **ARCHIVED** to `explorations/small_n/archived_cate_interface/` (NOT merged; reserved for continuous-X). The exact-IF se="if" derivation (IF_SE_derivation.md) is validated (IF-SE ≈ empirical SD; cross-outcome block matters) and reusable.
- Package on `main` unchanged: 8 R files, 13 exports.

**Next (build phase, when active):** implement the discrete disattenuation correction as a package bias-correction option (verified, CATE-free); then the continuous quadratic-functional debiasing. Open questions in CONTINUOUS_CASE.md §4 (geometry on a continuum; which learners expose a usable IF; one-step vs TMLE; joint n-and-M variance).
