# Observation-level estimand & the A0 (conditional-effect-transportability) assumption

**Status:** exploration (2026-07-09). Investigating whether a principled
observation-level (individual-perturbation) estimand exists and can escape A0
(the assumption that all cross-study effect variation is compositional in X).

## A0, named

The reweighting `Δ_S(Q)=E_{P₀}[w(X)τ_S(X)]` uses `w=w(X)` — a function of X only.
So every future study Q shares P₀'s conditional law of potential outcomes given X;
studies differ only in the marginal of X. **A0 = "effects transport conditional
on X"** (Dahabreh–Hernán class). If two units with the same X have different true
effects (unmeasured modifier U), a real future study could shift U|X — which
w(X) cannot represent. A0 was previously buried in "A3: Q ≪ P₀"; it is really a
substantive causal assumption and deserves its own name.

## The old "observation-level" code did NOT escape A0 (verified from git history)

`pre-realignment-2026-07-08:R/observation_level_minimax*.R`: it (a) estimated
τ(x) by smooth regression (kernel/RF/GAM) and (b) reweighted by covariate
DISTANCE (softmax `W[k,j]=exp(-‖x_k-x_j‖²/τ)`). The cost is `rowSums((X-X[j,])²)` —
**purely X**. Two units with identical X get identical weights ⇒ still X-level.
It was X-level reweighting with a smoother CATE + a Wasserstein geometry, not a
genuine individual-level construction. (This likely explains why it showed
"lower correlation due to noise" — an artifact.)

## A principled observation-level estimand DOES exist (probe `01`)

Define individual effects τ_S(X,U), τ_Y(X,U); obs-level future studies reweight
(X,U), not just X. Correlating (Δ_S,Δ_Y) over that larger class:
- **A0 holds (no within-X heterogeneity):** obs-level = X-level (both 1.00). ✓
- **within-X heterogeneity ALIGNED with X-effects:** still equal.
- **within-X heterogeneity OPPOSED:** X-level=1.00 but obs-level=0.84 — surrogate
  LESS reliable than X-level claims; X-level is blind to it.
- **X-effects uncorrelated + within-X correlated:** X-level=−1.00, obs-level=−0.55.

⇒ The obs-level estimand is well-defined, equals X-level iff A0 holds, and is
otherwise **less extreme (more conservative)**. The X-level/obs-level GAP genuinely
measures exposure to unmeasured within-X heterogeneity — NOT a noise artifact.
Your intuition was right.

## But it is only PARTIALLY identified from one study (probes `02`, `03`)

The obs-level correlation needs within-X moments v_S(x)=Var(τ_S|x),
v_Y(x)=Var(τ_Y|x), c_SY(x)=Cov(τ_S,τ_Y|x).
- **Variances v_S, v_Y: IDENTIFIED** — recoverable as Var(S|A=1,x)−Var(S|A=0,x)
  (verified; good recovery except in ~5%-mass cells).
- **Cross-covariance c_SY: NOT identified** — it is the correlation of potential
  outcomes (τ_S and τ_Y effects are never both observed on one unit). The naive
  difference-in-covariances estimator works ONLY if effects are independent of
  baselines within X; stress test `03` shows its error grows 0.05→0.56→1.21 as
  effect–baseline dependence increases. This is the classic PO-correlation
  non-identifiability, not fixable by better estimation.

## Synthesis (the honest framework)

- **Point estimand (X-level):** correlation under A0. What the method reports.
- **A0 is a genuine identification barrier for a point obs-level estimate** — you
  cannot escape it for a point value from one study.
- **BUT an honest INTERVAL is available:** identify v_S, v_Y; sweep the
  unidentified c_SY over its Cauchy–Schwarz-feasible range; report
  [ρ_obs_lo, ρ_obs_hi]. This is a **data-powered sensitivity analysis for A0** —
  the bounds are constrained by the observed within-X spread, not a free dial.
- Reframes the old "report both X-level and obs-level" as **"report the X-level
  point estimate and its A0-sensitivity bounds."**

## Next (to decide)

Prototype the bounds: (1) estimate v_S(x), v_Y(x) by arm-variance differencing;
(2) for c_SY(x) ∈ [−√(v_S v_Y), +√(v_S v_Y)] (Cauchy–Schwarz), compute the
obs-level correlation at the extremes → [ρ_lo, ρ_hi]; (3) validate the interval
covers the true obs-level correlation across the Scenario A–D DGPs. Open Q:
whether cross-cell structure tightens the CS bound; how the bound interacts with
the geometry (λ) and with small-n. Ties to GENERAL_THEORY.md A0/A5.
