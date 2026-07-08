# IF-based SE for the across-study correlation with general CATE estimation

**Status:** exploration derivation (2026-07-08). Reference for prototyping an
influence-function SE that replaces the bootstrap fallback in
`tv_ball_correlation_cate()`.

## Setup

Fix the sampler covariance `Σ = Σ_q = Cov_μ(q)` (from hit-and-run on the TV ball;
depends only on P₀ and λ, treated as fixed given the M draws). Let `τ_S, τ_Y ∈ ℝ^K`
be the cell CATE vectors. The estimand is

```
Θ(τ_S, τ_Y) = num / sqrt(a · b),
  num = τ_Sᵀ Σ τ_Y,   a = τ_Sᵀ Σ τ_S,   b = τ_Yᵀ Σ τ_Y.
```

Θ is smooth in the 2K-vector θ = (τ_S, τ_Y) wherever a, b > 0 (non-degeneracy).

## Gradient (analytic)

```
∂Θ/∂τ_S = (1/sqrt(a b)) [ Σ τ_Y − (num/a) Σ τ_S ]
∂Θ/∂τ_Y = (1/sqrt(a b)) [ Σ τ_S − (num/b) Σ τ_Y ]
g = (∂Θ/∂τ_S ; ∂Θ/∂τ_Y)  ∈ ℝ^{2K}
```

(Verify numerically against a finite-difference gradient in the prototype.)

## Delta-method variance

If `√n(θ̂ − θ) →_d N(0, nV)` with V the joint (O(1/n)) covariance of `θ̂`, then

```
Var(Θ̂) ≈ gᵀ V g,   SE(Θ̂) = sqrt(gᵀ V g).
```

## The covariance V — the crux

V is 2K×2K with blocks
```
V = [ V_SS  V_SY ;  V_SYᵀ  V_YY ].
```
- **V_SY (cross-outcome) is nonzero** and must be included: τ̂_S(k) and τ̂_Y(k) use
  the SAME observations and SAME treatment assignment in cell k, and S enters Y,
  so their estimation errors are correlated. A per-cell-variance-only plug-in
  (block-diagonal, V_SY = 0) gives the WRONG SE. Bootstrap captures V_SY
  automatically; an IF-SE must reconstruct it.

### General route: influence-function contract

Require the CATE estimator to return, per outcome, an influence matrix
`IF ∈ ℝ^{n×K}` with `τ̂(x_k) − τ(x_k) ≈ (1/n) Σ_i IF[i,k]`. Stack the two outcomes'
IF matrices columnwise and

```
V = Cov( [IF_S | IF_Y] ) / n          # 2K×2K, includes cross-outcome block
SE = sqrt( gᵀ V g )
```

This works for ANY estimator with an IF representation (saturated, AIPW,
DR-learner; grf via infinitesimal-jackknife pseudo-values).

### Exact IF for the saturated (per-cell) estimator

τ_S(k) = E[S|A=1,X=k] − E[S|A=0,X=k]. With cell probability p_k = P(X=k) and
in-cell propensity e_k = P(A=1|X=k), the influence contribution of observation i
to τ̂_S(k) is
```
IF_S[i,k] = 1(X_i = k)/p_k · [ A_i (S_i − m_{S,1,k}) / e_k
                              − (1−A_i)(S_i − m_{S,0,k}) / (1−e_k) ],
```
and IF_Y[i,k] is identical with Y and m_{Y,a,k}. Because of the 1(X_i=k) factor:
- cross-CELL covariance is 0 (disjoint units), so V_SS, V_YY are DIAGONAL;
- within-cell cross-OUTCOME covariance is nonzero via cov(S,Y | A, X=k) → V_SY is
  diagonal but nonzero. So V is block structure with K independent 2×2 blocks.
This is exact and cheap; the prototype validates IF-SE ≈ empirical SD ≈ bootstrap.

## Relationship to the canonical estimator

The canonical `tv_ball_correlation_IF_adaptive()` builds its IF over the M sampled
studies (reweighting path) and is unchanged. This derivation is the analogue for
the cell-CATE plug-in path, expressed in the cell-CATE parameterization, so a
general CATE learner's own IF propagates through the same delta method. Same
estimand, same functional-delta logic, different (equivalent) parameterization.

## Plan

1. Prototype `if_se_saturated()` using the exact IF above; validate vs empirical
   SD and bootstrap across n and both DGPs.
2. Define the extended CATE contract (`cate_fn` may return `if_mat`); assemble V
   and SE = sqrt(gᵀVg) generically.
3. If validated, fold into `tv_ball_correlation_cate(se = "if")` for the saturated
   path; document that other learners need to supply `if_mat`.

## VALIDATION RESULT (`07_if_se_prototype.R`, 150 reps)

Analytic gradient matches finite differences to 4e-10. IF-SE vs empirical SD:

| dgp | n | emp_sd | if_se (full V) | if_bd (block-diag) |
|-----|---|--------|----------------|--------------------|
| dgp1 | 500 | 0.458 | 0.434 | 0.444 |
| dgp1 | 1000 | 0.354 | 0.341 | 0.351 |
| dgp1 | 2000 | 0.296 | 0.290 | 0.299 |
| dgp2 | 500 | 0.261 | **0.231** | 0.213 |
| dgp2 | 1000 | 0.173 | 0.170 | 0.157 |
| dgp2 | 2000 | 0.114 | 0.105 | 0.096 |

- **IF-SE tracks empirical SD** (ratio ~0.92–0.98; slight under-estimate at small n,
  expected). Replaces the bootstrap fallback with a closed-form SE.
- **Cross-outcome block V_SY matters**, most for dgp2 (strong S–Y error correlation):
  full V (0.231) is closer to emp_sd (0.261) than block-diagonal (0.213). Confirms
  the naive per-cell-variance plug-in under-estimates; V_SY must be included.
- **Caveat:** this SE quantifies the estimator's sampling variability correctly, but
  the CI is centered on the ATTENUATED ρ̂, so small-n coverage of the TRUE ρ is still
  limited by bias (a separate problem from SE). IF-SE + a bias correction
  (disattenuation / better CATE) are complementary.

⇒ Fold `se = "if"` into `tv_ball_correlation_cate()` for the saturated path
(exact IF). General learners supply their own IF matrix via an extended contract.
