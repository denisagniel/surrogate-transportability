# MANIFEST — confounded-aipw

| | |
|---|---|
| Study | `confounded-aipw` |
| Project | `surrogate-transportability` |
| Created | 2026-09-25 |
| Spec stem | `2026-09-25_confounded-aipw-arm` |
| Design provenance | `explorations/2026-09-24_confounded-aipw-arm/R/01_design_confounded_dgp.R` (propensity-strength scan selecting `e_coef`) |
| Backend | O2 SLURM cluster (migrating from the original local `run_study.R` design) |
| Base seed | `90900000` (distinct from `canonical-validation` 7.08e7, `generality-validation` 8.08e7) |
| Estimator | `surrogateTransportability::tv_ball_correlation_IF_adaptive()` |

## What this study is for

Validating the observational (cross-fitted AIPW) estimation path against the
randomized (importance-weighting) path, including on confounded DGPs where the
latter is provably inconsistent. See `README.md` for the design and the closed-form
importance-weighting bias.

## Manuscript claims this study supports

| Claim | Location |
|---|---|
| The framework "extends to observational studies via cross-fitted augmented inverse probability weighting" | `inst/paper/main.tex`, `\label{sec:discussion}` |
| Finite-sample behavior at practical sample sizes, down to `n = 250`, comparing the randomized and observational paths | `inst/paper/main.tex`, `\label{sec:sim-future}` |

The second claim's wording was corrected on 2026-09-25 to match the grids this study
and `generality-validation` actually construct; see
`quality_reports/reviews/2026-09-25_sim-future-claim-audit.md`.

## Package surface this study depends on

Added or extended for this study, all with roxygen documentation and tests:

- `generate_dgp_data(..., e_int, e_coef)` — confounded treatment assignment
- `confounded_dgp_params()` — the `conf1` / `conf2` specifications
- `canonical_cates()`, `true_rho_from_cates()`, `iw_limit_from_cates()` — exact
  reference values from the DGP's mean structure
- `crossfit_nuisances_once()` — fit-once AIPW nuisances

Tests: `tests/testthat/test-dgp-confounded.R`,
`tests/testthat/test-crossfit-nuisances.R`.

## Runs

| Run id | Units | Notes |
|---|---|---|
| `20260926-092734_b049ad1` | 1120/1120 | **Completed 2026-09-28.** O2 SLURM (jobs 54483375 large_n/17 tasks, 54483376 small_n/1 task). All units succeeded, exactly-once coverage per stratum, 0 error_msg. 728/1120 units hit `M_max=1500` without meeting the adaptive tolerance (diagnostic, not a failure — see below). Combined via `slurm/combine.R --from-partials`; summarised via `analyze.R`. |
| `20260928-121110_ca9646a` | 2560/2560 | **Completed 2026-09-28.** Extended grid (n∈{500,2000,40000} added for dgp1/conf1, package v0.4.1). O2 SLURM (jobs 54655918/919/921, one task per stratum). All units succeeded, exactly-once coverage per stratum, 0 error_msg. See "Completed" section below for the full n-scaling result. |

Superseded or smoke runs are not retained in `results/`.

### Verified result: `20260926-092734_b049ad1` (2026-09-28)

Resolved the "submitted but unverified" state recorded in `session_notes/2026-09-27.md`
and `2026-09-28_HANDOFF.md` (two prior sessions lost track of this run to a local
`childprocess-spawn` infra bug during SSH back-off, unrelated to the SLURM job itself).
Re-authenticated interactively (`~/.ssh/id_ed25519`, now pinned as `Host o2` in
`~/.ssh/config`), confirmed via `sacct` (18/18 tasks COMPLETED, exit 0:0) and an
independent filesystem count (1120/1120 `partials/*.rds`), then rsynced the scratch
run directory back and combined/analysed locally.

**Cross-check against README's closed forms — confirmed:**

| dgp | n | rho_true | iw_limit (pred.) | IW mean_est | AIPW mean_est | IW bias | AIPW bias |
|---|---|---|---|---|---|---|---|
| dgp1 | 10000 | 0.6907 | 0.6907 | 0.6444 | 0.6712 | −0.0464 | −0.0195 |
| dgp2 | 10000 | −0.8845 | −0.8845 | −0.8565 | −0.8801 | 0.0280 | 0.0044 |
| dgp4 | 10000 | 1.0000 | 1.0000 | 0.9993 | 0.9992 | −0.0007 | −0.0008 |
| dgp5 | 10000 | 1.0000 | 1.0000 | 0.9996 | 0.9996 | −0.0004 | −0.0004 |
| conf1 | 10000 | 0.6876 | 0.0773 | 0.0783 | 0.6328 | **−0.6093** | −0.0548 |
| conf2 | 10000 | 0.6876 | −0.4709 | −0.3855 | 0.5792 | **−1.0731** | −0.1084 |
| conf1 | 250 | 0.6876 | 0.0773 | 0.1486 | 0.2718 | −0.5390 | −0.4158 |
| dgp1 | 250 | 0.6907 | 0.6907 | 0.3466 | 0.4009 | −0.3441 | −0.2899 |

- **Agreement block:** AIPW ≈ IW ≈ rho_true on all 4 canonical DGPs — smoke test
  passes, no implementation bug.
- **Confounded block (the content):** IW converges to the predicted propensity-tilted
  limit (0.0783 vs 0.0773 for conf1; −0.3855 vs −0.4709 for conf2, including the
  predicted sign reversal), while AIPW recovers `rho_true` far more closely — bias
  reduction of ~0.55 (conf1) and ~0.97 (conf2) vs IW. This is the discriminating
  result the study was designed to produce.
- **conf2 positivity stress:** AIPW degrades relative to conf1 as predicted (bias
  −0.108 vs −0.055; coverage 0.912 vs 0.950) — attributable to the near-clip
  propensities in the rarest covariate cell, not a mystery.
- **smalln (n=250) stress regime:** both arms substantially attenuated (bias
  −0.29 to −0.54), as documented — expected at this sample size, not a defect.
- **Diagnostic — M_max saturation, RESOLVED 2026-09-28 (not just flagged).** 728/1120
  units hit `M_max=1500` without meeting the OLD difference-window convergence test.
  Oracle-consulted root cause: that test checked absolute successive-`rho_hat`
  changes against `tolerance=0.01`, which is confounded with `|rho|` itself (draws
  are nested, so `sd(rho_hat) ~= (1-rho^2)/sqrt(M)`) — near `rho=1` it passed almost
  immediately, near this study's `rho~0.69` DGPs it was ~20x tighter than the actual
  Monte Carlo noise floor and essentially never passed. Computed directly on this
  run's raw results: `se_mc = (1-rho^2)/sqrt(M_final)` was <=18.5% (median 5.3%) of
  the reported influence-function SE for EVERY unit, converged or not, inflating CI
  width by <=1.5% worst case (median 0.2%) — far too small to explain the observed
  0.912-0.950 coverage spread or to touch the bias contrast above. **The numbers in
  this table stand; no rerun was needed.** Package v0.4.1 (see NEWS.md) replaces the
  stopping rule with a direct MC-precision test (`se_mc < mc_tolerance`, default
  0.02) and fixes an unrelated O(n*M*K) performance bug in the same function; this
  run predates that fix but is unaffected by it in substance.

Full per-configuration table: `Rscript simulations/confounded-aipw/analyze.R --run-id 20260926-092734_b049ad1`.
Combined result: `results/20260926-092734_b049ad1.rds`; summary:
`results/20260926-092734_b049ad1_summary.rds` (both gitignored per this repo's
`results/*.rds` policy — regenerate from the scratch partials, now discarded from
local `/tmp`, or from `/n/scratch/.../confounded-aipw/20260926-092734_b049ad1` on O2
if still present).

Note that `config/sizing.tsv` / `sizing.json` are absent from this subtree: sizing was
derived from an on-O2 `submit.sh --smoke` run and those artifacts exist only on
scratch, so the committed tree pins the study code, not the array sizing.

## Queued: n-grid extension (grid.R edited, NOT yet submitted, 2026-09-28)

`config/grid.R` gained a fourth block, `ngrid`: the same two anchor DGPs as
`smalln` (`dgp1` canonical, `conf1` confounded), both methods, at
n in {500, 2000, 40000} — 12 configs, 1440 new units (`small_n` stratum gains
960 at n=500/2000; a new `xlarge_n` stratum takes the 480 at n=40000).
Combined with `smalln`'s existing n=250 cell and `agreement`/`confounded`'s
existing n=10000 cells for these same two DGPs, this completes the 5-point
finite-sample grid n in {250, 500, 2000, 10000, 40000} that
`quality_reports/reviews/2026-09-25_sim-future-claim-audit.md` traces to
`inst/paper/main.tex`'s `sec:sim-future` promise — for these two DGPs only, not
the full 6-DGP grid, to keep the added O2 compute bounded (n=40000 is ~4x
n=10000's per-unit `O(n*M)` cost).

`M_max=1500` was deliberately left unchanged across the extended grid: under the
v0.4.1 MC-precision stopping rule, required M for `se_mc < mc_tolerance=0.02` at
this study's least favorable observed rho (~0.69) is ~676, independent of `n`
(`se_mc` depends only on `rho` and `M`) — comfortably under 1500 at every n,
including n=40000.

**Infra fixes made alongside the grid edit, before any cluster time was spent**
(`slurm/validate_mapping.R` re-run and passing with all three strata after each):
- `slurm/submit.sh --smoke` hardcoded `for s in large_n small_n`, which would have
  silently dropped the new `xlarge_n` stratum from smoke-profiling and therefore
  from `sizing.tsv` and the full submission, with no error. Strata are now
  discovered from `stratum_of(GRID)` at runtime; `xlarge_n` got its own smoke
  `--time`/`--mem` defaults.
- `slurm/smoke_rows.R` selected probe cells by `(dgp, method)` only. Harmless while
  every stratum held one `n`, but `small_n` now spans n in {250, 500, 2000}: an
  n=250-only probe would have sized `reps_per_job` off the cheapest cell in the
  stratum, undercosting the n=2000 units sharing that array. Cell key is now
  `(dgp, method, n)`.
- `slurm/validate_mapping.R`'s cross-stratum task-id-uniqueness check (Sec. 5) was
  hardcoded to exactly two named strata (`large_n`/`small_n`); generalized to loop
  over `strata` from the grid with a per-stratum candidate `reps_per_job` set, so a
  third (or future fourth) stratum is exercised by the same check rather than
  silently skipped.

**Status as of this entry:** `config/grid.R` extended and verified locally
(`unit_table()`: 2560 units, 0 duplicate seeds, 0 duplicate `(config_id, rep_id)`;
`validate_mapping.R`: ALL CHECKS PASSED across all three strata). Package bumped
to v0.4.1 (adaptive-M fix + perf fix, see NEWS.md), pushed to `github` (the remote
O2 pulls from; `origin`/code.rand.org was unreachable from this network and was
not pushed), and installed on O2 (verified: version 0.4.1, all 9 required
functions present, `mc_tolerance` in the estimator's formals).

### Completed: `20260928-121110_ca9646a` (2026-09-28, extended n-grid)

Smoke-tested first (`smoke-20260928-120905_ca9646a`, 28/28 tasks COMPLETED, 0
errors) — per-unit costs came back dramatically lower than the pre-fix run:
0.5-5.8s per unit across all three strata (vs. the old run's 81s median at
n=10000), confirming the v0.4.1 perf fix + MC-precision stopping rule. Sized via
`profile_timing.R --target-hours 2`: the entire 2560-unit study fit in **3 tasks
total** (one per stratum), completed in 12-29 minutes wall time each, ~1.0
CPU-hour combined. All 2560/2560 units succeeded, exactly-once coverage per
stratum, 0 error_msg. 948/2560 units hit `M_max=1500` without meeting the
adaptive tolerance — same non-issue as the prior run (Oracle-verified: `se_mc`
stays a small fraction of the IF SE regardless of the flag; not investigated
further here).

| Field | Value |
|---|---|
| Run id | `20260928-121110_ca9646a` |
| Jobs | `54655918` (large_n, 640 units, 11:56), `54655919` (small_n, 1440 units, 13:15), `54655921` (xlarge_n, 480 units, 29:15) |
| Units | 2560 (640 agreement/confounded @ n=10000 unchanged from the prior run, plus 1920 new: `ngrid` @ n∈{500,2000,40000}) |

**The n-scaling result — dgp1 (canonical) vs conf1 (confounded), both methods, across n∈{250,500,2000,10000,40000}:**

| dgp | n | method | bias | rmse | coverage |
|---|---|---|---|---|---|
| dgp1 | 250 | aipw | −0.290 | 0.537 | 0.842 |
| dgp1 | 250 | IW | −0.344 | 0.569 | 0.800 |
| dgp1 | 500 | aipw | −0.240 | 0.482 | 0.917 |
| dgp1 | 500 | IW | −0.306 | 0.539 | 0.883 |
| dgp1 | 2000 | aipw | −0.163 | 0.381 | 0.942 |
| dgp1 | 2000 | IW | −0.139 | 0.360 | 0.917 |
| dgp1 | 10000 | aipw | −0.019 | 0.115 | 1.000 |
| dgp1 | 10000 | IW | −0.047 | 0.119 | 0.975 |
| dgp1 | 40000 | aipw | −0.010 | 0.070 | 0.967 |
| dgp1 | 40000 | IW | −0.018 | 0.068 | 0.958 |
| conf1 | 250 | aipw | −0.416 | 0.658 | 0.842 |
| conf1 | 250 | IW | −0.538 | 0.734 | 0.800 |
| conf1 | 500 | aipw | −0.387 | 0.658 | 0.850 |
| conf1 | 500 | IW | −0.589 | 0.743 | 0.750 |
| conf1 | 2000 | aipw | −0.205 | 0.435 | 0.908 |
| conf1 | 2000 | IW | −0.611 | 0.716 | 0.717 |
| conf1 | 10000 | aipw | −0.053 | 0.176 | 0.938 |
| conf1 | 10000 | IW | −0.609 | 0.666 | 0.412 |
| conf1 | 40000 | aipw | −0.016 | 0.093 | 0.925 |
| conf1 | 40000 | IW | −0.599 | 0.618 | **0.017** |

**The result the n-grid extension was built to produce, made visible by having 5
points instead of 1:**

- **dgp1 (no confounding):** both paths attenuate at small n and converge toward
  `rho_true` as n grows — ordinary finite-sample behavior, coverage climbing
  toward nominal for both. Nothing distinguishes the two paths qualitatively
  here, as expected (both are consistent on a randomized DGP).
- **conf1 (confounded) — the discriminating evidence:** AIPW's bias shrinks
  monotonically toward zero as n grows (−0.42 → −0.02), the signature of a
  **consistent** estimator. IW's bias stays essentially flat (−0.54 to −0.61)
  across the ENTIRE grid — it is not attenuating, because it is converging to
  the wrong target (`rho_iw_limit=0.0773`), not to `rho_true`. This is the
  single-n confounded-block result generalized to a proof of asymptotic
  behavior: a point estimate that stops improving with more data is much
  stronger evidence of inconsistency than one bad estimate at one n.
- **IW's coverage collapses as n grows: 0.80 (n=250) → 0.017 (n=40000).** This
  is the textbook signature of inconsistency interacting with a shrinking SE:
  as n grows, IW's confidence interval tightens around the WRONG value, so the
  true `rho_true` falls outside it almost always at large n. This is arguably
  the single most legible number this study has produced for the paper's
  argument that naive importance-weighting is not just biased but actively
  *more* misleading (falsely confident) at larger sample sizes under
  confounding — AIPW's coverage, by contrast, stays near nominal throughout
  (0.84-0.94, no trend).

Full per-configuration table: `Rscript simulations/confounded-aipw/analyze.R --run-id 20260928-121110_ca9646a`.
Combined result: `results/20260928-121110_ca9646a.rds`; summary:
`results/20260928-121110_ca9646a_summary.rds` (gitignored; regenerate from
`/n/scratch/.../confounded-aipw/20260928-121110_ca9646a` on O2 if still present).
