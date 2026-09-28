# Results — generality-validation

## `INVALID_rng-bug_20260717-082417_5d07c37.rds` — DO NOT USE

Quarantined 2026-09-23. This file (24,000 rows, the random-DGP ensemble block
only; git SHA `5d07c37`) was produced before a fix (commit following
`f6cc5c0`) to `R/dgp.R`: `draw_random_dgp()` calls `set.seed(config$dgp_seed)`
internally to rebuild the DGP spec, which clobbered the RNG state `run_one()`
had set for per-replication *data* generation. Every replication within a
`dgp_kind == "random"` config therefore drew **identical data** — only the
spec varied across configs, not the data across reps within one.

The independence assumption behind every coverage/bias number in this file is
violated for all rows with `dgp_kind == "random"` (i.e. the whole file — Block
1a only was run). Its reported coverage (93.75% raw / 96.68% jackknife) is
**not evidence of anything** and must not be cited, quoted, or used to decide
whether to promote the jackknife correction.

Kept (not deleted) for the record. A fresh run under the fixed `R/dgp.R` is
required before this study's numbers can go anywhere near the paper.

See `session_notes/2026-09-23.md` for the full audit trail.
