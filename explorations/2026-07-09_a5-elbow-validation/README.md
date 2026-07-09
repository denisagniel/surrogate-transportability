# A5 elbow validation — simulation backing for Theorem A

**Goal:** Give the paper's newly promoted **Theorem A** (general √n asymptotic
normality via debiased bilinear functionals of the CATEs) and its **A5 elbow**
(`s_S + s_Y > d/2`) empirical backing. The continuous-X debiased estimator does
not exist in the package yet; this exploration builds and validates it.

**Status:** In Progress (started 2026-07-09). Fast-track exploration (60/100 bar).

## Approach (two stages)

- **Stage 1 — isolate the elbow, fixed known kernel.** Estimand
  `ψ_ab = E[τ_a(X) τ_b(X)]` (Dirac kernel). One-step 5-fold cross-fit debiased
  estimator with a **fixed-smoothness sieve** CATE learner (NOT grf — grf adapts
  to smoothness and would mask the elbow). Continuous-X DGP with a Sobolev
  smoothness knob `s` and dimension `d`; design points straddle `s_S+s_Y=d/2`.
  Headline result = the **elbow signature**: slope of `log(SD)~log(n)` ≈ −1/2 and
  nominal coverage *above* the elbow; shallower slope + coverage collapse *below*.
  Then a **smooth-kernel** variant shows the kernel relaxes the Dirac elbow.
- **Stage 2 — end-to-end Θ, conditional on geometry.** Discretize X into cells to
  sample the TV-ball geometry (`sample_tv_ball` → Σ), estimate CATEs on continuous
  X with cross-fit grf, plug into three debiased quadratic functionals, compose the
  correlation Θ, IF-based SE via the validated `07_if_se_prototype.R` machinery.
  Coverage above vs near the elbow.

## Two thresholds (important)

The A5 elbow `s_S+s_Y > d/2` is the functional's *information-theoretic*
estimability boundary — but it is **attained only by higher-order influence
function (HOIF) estimators**. Theorem A constructs a **first-order one-step**
estimator, whose remainder `∫(τ̂_S−τ_S)(τ̂_Y−τ_Y)dP₀` is `o(n^{−1/2})` only when
the sum of L² rate exponents `s_S/(2s_S+d)+s_Y/(2s_Y+d) > 1/2`, i.e. (equal case)
**`s_S+s_Y > d`**. So the honest boundary for the estimator the paper builds is
`s_S+s_Y > d`, and there is a **gap** regime `d/2 < s_S+s_Y ≤ d` where the
functional is √n-estimable in principle but the first-order estimator is not.
Confirming this gap empirically is the evidence for a paper fix (state `>d` for
the one-step estimator; `>d/2` is the HOIF limit).

## Design points (Stage 1)

| id        | d | s_S | s_Y | sum  | vs d/2 (HOIF) | vs d (1st-order) | regime |
|-----------|---|-----|-----|------|---------------|------------------|--------|
| A_above   | 1 | 0.8 | 0.8 | 1.6  | above         | above            | above  |
| D2_above  | 2 | 1.2 | 1.2 | 2.4  | above         | above            | above  |
| E_edge    | 1 | 0.5 | 0.5 | 1.0  | above         | at boundary      | gap/edge |
| G_gap     | 1 | 0.4 | 0.4 | 0.8  | above         | below            | gap    |
| B_below   | 1 | 0.2 | 0.2 | 0.4  | below         | below            | below  |

**G_gap is the discriminator**: `sum=0.8 > d/2=0.5` (HOIF-estimable) but
`sum=0.8 < d=1` (first-order fails). If the one-step estimator degrades here, the
first-order boundary `s_S+s_Y>d` is confirmed and the paper's `>d/2` claim for the
one-step estimator must be corrected.

## Layout

Mirrors `simulations/canonical-validation/` for a clean graduation path:
`config/grid.R` (single source of truth), `R/` (dgp, estimator, run_one),
`scripts/` (local drivers + figures), `output/`, `slurm/` (added only if we scale).

## Decision (to be filled at the end)

Graduate (estimator → package `R/`, study → `simulations/`) if the elbow signature
is clean and coverage validates; otherwise document and iterate/archive.
