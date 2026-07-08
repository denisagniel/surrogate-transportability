# Continuous-X and the small-n correlation bias as a quadratic-functional problem

**Status:** scoping analysis (2026-07-08). Theory framing + verified core claim;
no heavy implementation. Decides the direction for the continuous-X extension and
unifies it with the discrete small-n bias correction.

---

## 0. The reframe that organizes everything

The across-study correlation is
```
Θ = Cov_μ(Δ_S, Δ_Y) / sqrt( Var_μ(Δ_S) · Var_μ(Δ_Y) ),
```
and each of the three building blocks is a **quadratic functional of the CATE
function τ**. With the sampler covariance Σ = Cov_μ(q) (fixed given the M draws):

- discrete X: `Var_μ(Δ_S) = τ_Sᵀ Σ τ_S`, `Cov_μ = τ_Sᵀ Σ τ_Y`, quadratic in the
  cell-CATE vectors τ_S, τ_Y ∈ ℝ^K.
- continuous X: `Var_μ(Δ_S) = ∬ C(x,x') τ_S(x) τ_S(x') dx dx'` with kernel
  `C(x,x') = Cov_μ(w(x), w(x'))·p₀(x)p₀(x')` — a quadratic functional of τ_S(·).

**Therefore the small-n bias of Θ̂ is the plug-in bias of quadratic functionals of
τ**, and disattenuation is exactly the first-order (one-step) debiasing of such
functionals. This single principle covers discrete AND continuous X.

### Verified (discrete, `/tmp/quadratic_check.R`)

Plug-in `E[τ̂ᵀΣτ̂] = τᵀΣτ + tr(ΣV)` where V = Cov(τ̂). At n=400, dgp1, S-block:
- true `τᵀΣτ` = 0.0253
- naive plug-in mean = 0.0261 (bias **+0.0008** = tr(ΣV))
- `tr(ΣV̂)`-corrected mean = 0.0250 (bias **−0.0003**) → bias removed.

The naive correlation attenuates because both denominator quadratic forms are
inflated by their `tr(ΣV)` terms; correcting them de-attenuates ρ̂. dgp2 (earlier
test) confirmed the full correction (numerator cross-term included) works:
bias +0.14 → −0.04 at n=500.

---

## 1. Why continuous X is structurally different (not "more cells")

1. **τ(x) must be estimated as a function.** Discrete X gave a free nonparametric
   τ (per-cell means) — the reweighting estimator IS that plug-in, which is why
   CATE estimation was a distraction there. Continuous X has no cells: forming
   `Δ_S(Q) = E_{P₀}[w(X) τ_S(X)]` for an arbitrary reweighting w requires τ_S(·)
   as an actual estimated function. **Here CATE estimation is unavoidable** — the
   archived pluggable interface is the continuous-case tool.

2. **The geometry is infinite-dimensional.** "Uniform on the TV ball of densities"
   and hit-and-run on the simplex don't directly transfer. Options: (a) discretize
   X into cells (recovers the discrete method + discretization bias — this is the
   RF-ensemble idea from the deprecated paper), or (b) reformulate the geometry
   over reweighting functions w(·). Open design question.

3. **Noise and regularization bias entangle.** Discrete per-cell means have NO
   regularization: the plug-in bias is pure noise, `tr(ΣV)`, cleanly subtractable.
   A continuous CATE learner (grf/BART/series) regularizes τ̂ toward smoothness,
   which ALSO shrinks Var_μ(Δ_S) — a bias that is NOT a clean noise term. So naive
   disattenuation does not directly generalize; the correction must target the
   quadratic functional itself, using the learner's influence function.

---

## 2. The quadratic-functional route (chosen framing)

Estimating `ψ(τ) = ∬ C(x,x') τ(x) τ(x') dxdx'` (and the bilinear cross-term) is a
**quadratic-functional estimation problem**, for which the semiparametric
literature gives first-order-unbiased ("one-step" / debiased) estimators:

```
ψ̂_debiased = ψ(τ̂) − [first-order bias term]
```
where the correction is built from the CATE estimator's influence function and is
computed with **cross-fitting** so the τ̂ used for the plug-in is independent of
the data used for the correction (kills the O(τ̂−τ)² regularization-bias cross
term to first order). This is exactly the machinery in the paper's
`proof_asymptotic_normality.tex` (Neyman orthogonality, cross-fitting,
o_p(n^{-1/4}) nuisance rates) — so the continuous correction is a natural
extension of the existing theory, not a new apparatus.

**Discrete case is the special case:** τ̂ = cell means (IF = per-cell AIPW score),
the quadratic functional is τᵀΣτ, and the debiasing term is exactly tr(ΣV̂). The
IF-SE work (IF_SE_derivation.md, se="if") already computes the needed IF and V.

### The unified correction (both cases)

```
Θ̂_debiased = ĉov_debiased / sqrt( v̂ar_S,debiased · v̂ar_Y,debiased )
  v̂ar_S,debiased = τ̂_Sᵀ Σ τ̂_S − tr(Σ V̂_S)        [discrete]
                 = ψ_S(τ̂_S)     − B̂_S              [continuous, one-step bias B̂_S]
  ĉov_debiased   = τ̂_Sᵀ Σ τ̂_Y − tr(Σ V̂_SY)        (cross-noise term; nonzero!)
```
plus a denominator floor + clamp to [−1,1] (the naive version overshot without
these — see 02/03).

---

## 3. Three routes to continuous X (ranked)

1. **Quadratic-functional debiasing (chosen target).** Most rigorous; unifies
   discrete + continuous as one first-order correction; reuses the paper's
   semiparametric machinery. Research-level but well-posed. Needs: CATE learner
   with an IF (grf via infinitesimal jackknife, or a series/DR-learner with a
   clean IF), cross-fitting, and the geometry reformulation (§1.2).
2. **Cross-fit CATE + honest-noise disattenuation.** The practical instantiation
   of route 1 short of full theory: cross-fit τ̂, estimate the noise term from the
   held-out folds, subtract. Bridges to route 1.
3. **Discretize + reuse discrete method.** Shippable now; data-adaptive binning +
   tr(ΣV) correction; cost = discretization bias. Good baseline/fallback.

---

## 4. Open questions for the build phase (not resolved here)

- **Geometry on a continuum:** discretize (route 3) vs reweighting-function ball
  (route 1b)? The estimand's meaning depends on this choice.
- **Which CATE learners expose a usable IF** for the debiasing term? saturated ✔,
  DR-learner ✔, grf (infinitesimal jackknife) ?, BART (posterior) needs a
  different (Bayesian) treatment.
- **Does the one-step correction suffice, or is a full TMLE-style iteration
  needed** for the ratio functional Θ (it's a smooth function of three quadratic
  functionals — delta method should suffice under non-degeneracy)?
- **MCMC (Σ_q) variability** enters the continuous case the same way; per the
  user decision, derive the JOINT (n and M) variance, with the conditional-on-M
  SE as its n=o(M) limit (consistent with the canonical estimator).

---

## 5. Recommendation

Treat the small-n correlation bias — discrete and continuous — as ONE problem:
**debiased estimation of quadratic functionals of τ.** Discrete disattenuation
(tr(ΣV)) is the verified special case and can go into the package now as a bias
correction (not "better CATE"). The continuous extension is the same correction
with a functional bias term + cross-fitting, and is the natural next methods
contribution, reusing the paper's existing semiparametric theory. CATE estimation
is a distraction for discrete X but genuinely required for continuous X — where it
enters as the plug-in inside the quadratic functional, not as the end goal.
