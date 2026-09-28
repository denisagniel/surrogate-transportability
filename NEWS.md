# surrogateTransportability 0.4.1

## Estimator: adaptive-M stopping rule

* `tv_ball_correlation_IF_adaptive()` now stops growing `M` on a **direct Monte
  Carlo precision test** rather than a difference-window test. A new argument
  `mc_tolerance` (default `0.02`) sets the target: the loop stops once
  `se_mc = (1 - rho_hat^2) / sqrt(M)` falls below it.

  The old rule — a sliding window of `n_stable + 1` raw `rho_hat` values, all of
  whose consecutive changes and whose cumulative change had to be below
  `tolerance` (default `0.01`) — was confounded with `|rho|` itself. Because the
  `Q` draws are nested (pre-sampled once at `M_max`, with `rho_hat` recomputed on
  the growing cumulative subset), the sampling sd of `rho_hat` is
  `(1 - rho^2) / sqrt(M)`. Near `rho = 1` that is minuscule and the rule passed
  almost immediately; near `rho ~ 0.7` — the paper's DGPs of interest, including
  the confounded-AIPW study — `0.01` sits roughly 20x below the actual Monte
  Carlo error floor and the rule essentially never passed, even at `M_max = 1500`.
  Verified on a completed 1120-unit simulation run: `se_mc` was at most 18.5%
  (median 5.3%) of the influence-function SE for *every* unit, converged or not,
  i.e. the old `converged` flag carried no information about Monte Carlo adequacy.

* **New return field `se_mc`**: the plug-in Monte Carlo standard error at the
  final `M`. Returned unconditionally — on the converged path, on the
  `M_max`-without-convergence path, and on the gradient-undefined early return.
  `mc_tolerance` is also echoed back in the returned list.

* **Deprecated (but retained)**: `tolerance` and `n_stable` are no longer used by
  the stopping logic. They remain in the signature, and are still echoed in the
  return value, so existing named calls in `simulations/confounded-aipw/` and
  `simulations/generality-validation/` keep working unchanged.

## Performance

* Fixed an O(n * M * K) hot spot in `tv_ball_correlation_IF_adaptive()`. Seven
  weight constructions (bootstrap observation probabilities, importance weights,
  AIPW cross-fitting observation weights, and their counterparts in the
  influence-function loop) each performed a `which(X_unique == data$X[i])` linear
  search inside a loop over observations nested inside the loop over `M` draws.
  The observation-to-cell map is now computed once as
  `k_idx <- match(data$X, X_unique)` and the weights are formed by vectorized
  indexing — the same idiom already used by `.jackknife_rho_iw()`.

## Validation

* New `validation/validate_mc_error_formula.R`: runs the estimator 50 times on a
  fixed dataset at fixed `M = 1500`, varying only the sampler seed, and compares
  the empirical sd of `rho_hat` to the plug-in `(1 - rho^2) / sqrt(M)` to check
  that residual hit-and-run autocorrelation does not inflate the true Monte Carlo
  error beyond the formula.
