# Proposal: pluggable `cate_estimator` for the TV-ball correlation

**Status:** exploration output (fast-track). A design recommendation, not yet
implemented in the package. 2026-07-08.

## Motivation (evidence)

Small-n bias in `Θ̂` is driven by noisy cell CATEs inflating the correlation
denominator (attenuation toward 0; bias −0.37→−0.10 for dgp1 as n:250→2000). The
fix is better CATE estimation, but it must **generalize to unknown DGPs** and
**never manufacture correlation**. Prototyping (explorations/small_n/) established:

- **Fixed-basis CATE models are unsafe:** poly2 collapses ρ̂ to ±1 in 9–33% of
  reps on realistic non-polynomial shapes. Reject.
- **Off-the-shelf, cross-fit, data-adaptive learners generalize:** grf
  (causal_forest, per outcome, W.hat=0.5) had collapse-rate 0 across all tested
  shapes AND reduced attenuation on both few-level and continuous X, at no
  variance cost.
- The generalizable abstraction is a **per-outcome CATE function**; running it
  separately on S and Y is the structural guard against manufactured correlation.

## Proposed API

Add to the estimator:

```r
tv_ball_correlation_IF_adaptive(
  data, lambda,
  cate_estimator = c("reweight", "saturated", "grf"),  # or a user function
  ...
)
```

- **`cate_estimator`**: string selecting a built-in, or a user function with the
  contract `function(y, A, X, x_eval) -> list(tau, var)` (one outcome; `var` may
  be NA). Built-ins: `reweight` (current default; IF-SE valid), `saturated`
  (per-cell diff-in-means for few-level X), `grf` (continuous/multivariate X).
- **Default:** `reweight` (unchanged — preserves the validated IF inference and
  three-way fidelity). grf is opt-in.
- **Separate-per-outcome is enforced** by the contract; document the ban on
  shared-structure / fixed-basis learners (collapse risk) prominently.

## Inference contract (must be explicit, not hidden)

- The influence-function SE is **derived only for the reweighting path.** A
  plugged-in learner changes the point estimate and invalidates that SE.
- ⇒ `cate_estimator != "reweight"` forces `se = "bootstrap"` (nonparametric,
  over observations) or `se = "none"`; requesting IF-SE errors. The prototype
  enforces this.

## Small-n honesty (independent of CATE choice)

- Report `Θ̂(λ)` across a λ-grid, not a single λ.
- Emit a small-n diagnostic (e.g. min effective obs/cell/arm) and warn when the
  reweighting path is likely attenuated.
- Disattenuation correction: promising but the naive version overshoots
  (needs a real noise estimate + denominator floor). Ship as experimental,
  off by default.

## Scope / effort to productionize

- New `cate_estimator` arg + dispatch + the two new built-ins (`saturated`
  trivial; `grf` adds a Suggests dep on `grf`).
- Bootstrap SE path (exists in prototype).
- Tests: contract conformance, separate-per-outcome, collapse guard, and that the
  default path is byte-identical to current behavior.
- Manuscript: this is exactly the deferred "finite-sample behavior at small n"
  work (main.tex §Further numerical studies) — the write-up can cite these results.

## Recommendation

Fold the interface into the package **as opt-in** (default unchanged), so the
validated canonical path is untouched while users in their own (possibly
continuous-X, non-polynomial) DGP get a safe, generalizable CATE option. Decide
production timing separately from this exploration.
