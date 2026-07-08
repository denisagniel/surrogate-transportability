# Small-n CATE estimation — exploration findings (2026-07-08)

**Status:** in progress (fast-track exploration, ~60/100). On branch `main`,
sandbox in `explorations/small_n/`.

## Problem

The TV-ball correlation estimator is well-calibrated at n=10,000 but **biased at
small n**. Mechanism: `Θ = cor_μ(Δ_S, Δ_Y)` is, in closed form, a Σ_q-weighted
correlation of the cell CATE vectors `τ_S, τ_Y`:

```
Θ = (τ_Sᵀ Σ_q τ_Y) / √( (τ_Sᵀ Σ_q τ_S)(τ_Yᵀ Σ_q τ_Y) )
```

The plug-in uses noisy raw cell CATEs `τ̂ = τ + ε`; the noise inflates the
denominator quadratic forms → **ρ̂ attenuated toward 0** (errors-in-variables).
Worst in sparse cells (X=±2 have ~5% mass each).

## Baseline (raw per-cell diff-in-means, 60 reps, `01_characterize_small_n.R`)

| dgp | n | truth | mean ρ̂ | bias | emp_sd | coverage |
|-----|---|-------|--------|------|--------|----------|
| dgp1 | 250 | 0.69 | 0.33 | **−0.37** | 0.51 | 0.88 |
| dgp1 | 500 | 0.69 | 0.35 | −0.35 | 0.47 | 0.85 |
| dgp1 | 1000 | 0.69 | 0.46 | −0.23 | 0.40 | 0.93 |
| dgp1 | 2000 | 0.69 | 0.59 | −0.10 | 0.29 | 0.88 |
| dgp2 | 250 | −0.88 | −0.62 | +0.26 | 0.38 | 0.90 |
| dgp2 | 500 | −0.88 | −0.70 | +0.19 | 0.31 | 0.93 |
| dgp2 | 1000 | −0.88 | −0.80 | +0.09 | 0.13 | 0.95 |
| dgp2 | 2000 | −0.88 | −0.86 | +0.02 | 0.09 | 0.95 |

**Key reads:**
- Strong attenuation bias toward 0, decaying with n. Dominant problem at n≤500.
- SE/SD ratio ~0.8–1.2 and coverage 0.85–0.95: CIs are ~right *width* but
  centered on an attenuated estimate. **Fix the point estimate, not the variance.**

## CATE survey (see task) — key takeaways

- With only 5 levels of X, raw per-cell diff-in-means IS the nonparametric MLE;
  heavy ML CATE machinery (grf/BART) is mostly wasted here — matters more for the
  FUTURE continuous/multivariate-X case.
- Real small-n levers: **shrinkage (ebnm/EB)** + **disattenuation correction**;
  **polynomial-in-X** as a middle bias-variance option.
- **TRAP (guardrail):** any CATE model that ties τ_S and τ_Y functional forms, or
  a linear-in-X fit when τ_Y is quadratic, forces cor→±1. Must estimate τ_S, τ_Y
  SEPARATELY and flexibly enough (≥ quadratic). `linearX` arm included to detect this.
- Shortlist to prototype: saturated+SE (baseline), EB shrinkage, poly2, grf
  (future-proofing), bartCause. Only `marginaleffects` currently installed;
  shrinkage/poly/disatten are base-R so prototyped without installs.

## Prototype design

`02_cate_estimators.R`: pluggable CATE estimators evaluated via the closed form
against a shared per-dataset Σ_q (sampled once) — fast, isolates the CATE effect.
Estimators: raw, shrink (EB), poly2, linearX (guardrail), disatten (denominator
noise correction). `03_compare_estimators.R`: 200-rep bias/variance/collapse-rate
across the n-grid.

Single-dataset smoke (n=500): `linearX` = ±1.000 (guardrail FIRES as predicted);
`poly2` captures curvature but small-n overshoots; `raw` sign-unstable on unlucky
draws. Multi-rep results pending (`03`, compare_summary.rds).

## n=250 robustness spikes (5-seed smoke, true ρ=0.69)

Sparse ±2 cells (~12 obs) can leave an arm with <2 obs; `cate_raw` now falls back
to pooled arm mean/variance (documented). Observed per-seed at n=250:
- `raw`: swings 0.32–0.85 (huge variance)
- `shrink`: can flip **negative** (−0.32) — over-shrink toward grand mean when cells noisy
- `poly2`: more stable, low-biased (0.36–0.88)
- `disatten`: **unstable** — NA (denominator over-corrected < 0) and >1 (1.2, nonsensical)
  because the per-cell variance estimates are themselves noisy at n=250.

⇒ At n=250 no simple fix is a clean win; multi-rep averages needed. Disattenuation
likely needs a denominator floor/cap (v2) to prevent overshoot.

## Multi-rep comparison result (200 reps, `03_compare_estimators.R`)

Bias / RMSE / collapse-rate (fraction pinned at |ρ̂|>0.999) by estimator:

- **raw**: attenuated (dgp1 bias −0.29→−0.17; dgp2 +0.35→+0.05), collapse ~0.
- **shrink (EB)**: NO better, often slightly worse — shrinking τ toward its mean
  attenuates the correlation further. Not a fix.
- **poly2**: helps **dgp2** a lot (bias +0.19→+0.02, lowest RMSE) because τ_Y is
  truly quadratic and poly2 captures it. For **dgp1** it lowers bias but RAISES
  variance → RMSE wash. Small collapse rate 0.02–0.035.
- **linearX (guardrail)**: collapse rate **1.000** everywhere — confirms a too-rigid
  CATE model forces cor→±1. Never use.
- **disatten (naive)**: **FAILED** — noisy plug-in cell-variances over-correct:
  ~40–58% of reps go NA (denominator<0) or overshoot |ρ̂|>1 at small n. Unusable
  as written; needs a properly-estimated noise term + denominator floor.

**Verdict: nothing generalizes.** poly2 "winning" for dgp2 is just exploiting
known quadratic curvature — it would misfire on a different CATE shape. shrink and
naive-disatten don't help. This over-indexes on the linear/quadratic DGP.

⇒ The real question is a GENERALIZABLE procedure (see GENERALIZABLE_APPROACH.md):
data-adaptive, per-outcome CATE learner (CV-selected flexibility, cross-fit) +
an assumption-free measurement-error correction with a real noise estimate.

## Generalizability test: grf vs poly2 vs raw on non-polynomial DGPs (`05`)

3 shape-varied DGPs on CONTINUOUS X (threshold, sinusoid, monotone-nl),
discretized to 10 cells, 120 reps. Bias / RMSE / collapse-rate:

| DGP | n | raw | poly2 | grf |
|-----|---|-----|-------|-----|
| threshold | 500 | bias −.01, rmse .042, coll 0 | bias +.045, rmse .048, **coll .09** | bias +.005, **rmse .035**, coll 0 |
| threshold | 1000 | −.01/.031/0 | +.042/.044/.008 | −.01/**.031**/0 |
| sinusoid | 500 | −.025/.062 | −.052/**.092** | −.016/**.060** |
| sinusoid | 1000 | −.003/.035 | −.024/.051 | −.004/**.039** |
| monotone_nl | 500 | −.048/.057 | −.006/**.011**/**coll .29** | −.024/.031 |
| monotone_nl | 1000 | −.025/.030 | −.004/.008/**coll .33** | −.027/.034 |

**Reads:**
- **grf generalizes:** competitive-or-best RMSE on ALL three shapes, **collapse
  rate 0 everywhere**. Never manufactures correlation. Confirms the
  off-the-shelf-CATE recommendation.
- **poly2 is unsafe:** best RMSE on monotone_nl (its curvature suits a quadratic)
  BUT **collapse rate 0.29–0.33** there and 0.09 on threshold — i.e. it pins ρ̂ at
  ±1 in up to a third of reps. Low mean RMSE hides a dangerous failure mode. This
  is the manufacture-correlation trap firing on realistic shapes, not just linearX.
- **raw is safe but noisier:** collapse 0 always, higher RMSE than grf at small n.
- **IMPORTANT nuance:** all three true ρ here are HIGH (0.88–1.0). These shapes
  didn't produce a low/moderate-ρ non-polynomial case — the sharper attenuation
  test (like dgp1's ρ=0.69) at non-polynomial shape is still untested. So grf
  "wins" but the small-n attenuation gap is modest here because truth is near 1.

**Bottom line for the user-facing recommendation:** use an off-the-shelf,
data-adaptive, cross-fit CATE learner (grf) run SEPARATELY per outcome. It is the
generalizable default: adapts to unknown CATE shape, does not collapse. Fixed-basis
models (poly2) are unsafe (collapse). Disattenuation remains a generic top-up.

## Pluggable interface prototype (`06_cate_interface.R`) + grf on few-level X

Prototyped `tv_ball_correlation_pluggable(data, lambda, cate=, ...)`: a CATE
estimator is any `(y,A,X,x_eval)->list(tau,var)` run SEPARATELY per outcome.
Built-ins: `raw`, `grf`. Inference: IF-SE only valid for `raw` (reweighting
derivation); other learners -> bootstrap SE (enforced, not faked).

grf vs raw on the 5-level canonical dgp1 (truth 0.69, 40 reps, n=1000):
- raw: bias **−0.075**, sd 0.238
- grf: bias **−0.009**, sd 0.236

⇒ grf reduces attenuation even on FEW-level X, same variance, no collapse.
(A single unlucky draw showed grf=0.83 overshoot — multi-rep corrected it; do
not trust single draws.) Combined with the shape-varied result (grf collapse-rate
0 across threshold/sinusoid/monotone-nl), grf is a strong, SAFE, generalizable
default across both few-level and continuous X.

**RECOMMENDATION (evidence-backed):** package exposes `cate_estimator=` with a
cross-fit, data-adaptive default (grf), documented separate-per-outcome contract,
+ bootstrap SE for non-default learners, + disattenuation option, + small-n
diagnostic. Fixed-basis models (poly) rejected: collapse to ±1 in 9-33% of reps.

## Open / next

- Read `03` multi-rep results → pick winner by RMSE with collapse_rate≈0.
- Disattenuation numerator cross-term (cov(ε_S,ε_Y) per cell, since S enters Y)
  currently approximated as 0 — refine if disatten looks promising.
- If a winner emerges: decide whether it becomes a `method=`/CATE option in the
  package estimator (production) or stays exploratory.

## MAJOR REFRAME (2026-07-08): CATE was a distraction; it's a quadratic-functional bias

Established (with the user) that for DISCRETE X, CATE estimation is a
computational intermediate the reweighting estimator already performs — there is
no separate CATE problem. The small-n issue is **O(1/n) attenuation of the
correlation FUNCTIONAL** (confirmed by an n×M factorial: bias tracks n, not M —
n:500→4000 cut dgp1 bias −0.28→−0.09; M:300→3000 barely moved it).

Reweighted ATEs Δ̂(Q) are ~unbiased; the bias is in correlating noisy estimates:
denominator quadratic forms inflate by tr(ΣV)=O(1/n). This reduces to the plug-in
bias of QUADRATIC FUNCTIONALS of τ, which has a known first-order correction
(verified: subtracting tr(ΣV̂) de-biases τ'Στ). See CONTINUOUS_CASE.md for the
unifying theory (discrete disattenuation = special case; continuous = same
correction + functional bias term + cross-fitting; reuses the paper's
semiparametric machinery).

**Pluggable CATE interface ARCHIVED** (archived_cate_interface/) — reserved for
the continuous-X case where a τ(x) regression is genuinely required.
