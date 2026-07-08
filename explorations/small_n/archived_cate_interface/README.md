# Archived: pluggable CATE interface

**Archived 2026-07-08.** These files were prototyped as a package feature
(branch `feature/pluggable-cate`, not merged) but **archived** after we
established that, for the canonical **discrete-X** method, CATE estimation is a
computational intermediate the reweighting estimator already performs — there is
no separate CATE problem, so this interface solved a non-problem there.

Contents (do not source into the package):
- `cate_estimators.R` — `cate_estimator()` pluggable family (saturated, grf)
- `tv_ball_correlation_cate.R` — estimator with pluggable CATE + se="if"/bootstrap
- `test-cate-estimators.R` — its tests

**Why kept, not deleted:** the interface (and its exact-IF `se="if"` machinery)
is the right starting point **if/when continuous or high-dimensional X becomes an
active target**, where per-cell means are impossible and a genuine CATE
regression is required. See `../CONTINUOUS_CASE.md` for that analysis.

The feature branch `feature/pluggable-cate` retains the full history if needed.
