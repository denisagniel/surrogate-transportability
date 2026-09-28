# Run Manifest -- lambda-sweep

Spec stem: none (this study was specified in its own `README.md`, not in
`quality_reports/specs/`).

**Status as of 2026-09-25 16:52 ET: COMPLETE.** All 18 tasks COMPLETED, 720/720
units, 0 failed replications, combined to
`results/20260925-152042_b049ad1_reps20.rds`. See §5.

---

## 1. Backend migration (2026-09-25): local-only -> Harvard O2 SLURM

This study's `README.md` originally argued for a local-only backend on two grounds.
The second of them has expired:

> "O2 can only run what git delivers, and this track is not permitted to commit."

That restriction no longer applies, so the study now has its own O2 scaffold under
`slurm/`, independent of `canonical-validation`'s (one subtree per study, per the
`setup-cluster-simulations` convention). The science files — `R/run_one.R`,
`R/estimators.R`, `R/dgp.R`, `R/cell_cates.R`, `R/exit_interior_prediction.R` —
were **not modified**; `run_one()` already kept the cluster contract. `config/grid.R`
was also left untouched.

`local/run_local.R` and `local/combine.R` remain in place and still work; the O2
path is additive.

### Code delivery note (why rsync, not `git push`)

`simulations/lambda-sweep/` is **untracked** in git as of this migration, and this
task was not permitted to commit. The package itself is delivered by git — commit
`b049ad1` was pushed to `github/main` (an already-existing commit; nothing new was
committed) and `git pull --ff-only` + `R CMD INSTALL .` ran on O2. The study subtree
itself was delivered with `rsync` to `transfer.rc.hms.harvard.edu`, per
`simulations/TRANSFER.md`. **Consequence:** until this subtree is committed and
pushed, an O2 re-run depends on that rsync being repeated; the recorded `git_sha`
on every result row pins the *package*, not this scaffold. The scaffold is pinned
instead by the code hash below.

---

## 2. Provenance decision: the 236 local partials were DISCARDED, not reused

A local run under run-id `20260925-121424_df1ebc5` left 236 completed unit results
at `results/partials/20260925-121424_df1ebc5/unit_NNNNNN.rds` (of the 720 units
that constitute reps 1–20). Those files are **preserved, unmodified, and not fed
into the O2 run.** The reasoning, on two independent axes:

### Axis 1 — estimator/DGP code: PASSES (reuse would have been safe here)

`git diff df1ebc5..HEAD` on the two files `R/estimators.R` actually calls:

```
git diff df1ebc5..HEAD -- R/tv_ball_correlation_IF_adaptive.R R/tv_ball_sampling.R
  -> EMPTY (0 lines)
```

However, the diff over the whole package was *not* empty, and one changed file is
on this study's critical path: **`R/dgp_canonical.R`** (+159/−5), which provides
both `canonical_dgp_params()` and `generate_dgp_data()`. Two sub-checks:

* `canonical_dgp_params()`'s body is byte-identical between `df1ebc5` and `HEAD`,
  and all four `rho_true` values are unchanged (0.6907059, −0.8844963, 0.999997,
  0.999996) — so `true_value()`'s `package_mc_reference` branch is unaffected.
* `generate_dgp_data()` **did** change on its RNG path: `A <- stats::rbinom(n, 1, 0.5)`
  became `A <- .assign_treatment(X, X_levels, e_int, e_coef)`. On the RCT path this
  study uses (`e_int`/`e_coef` both `NULL`), `.assign_treatment()` reduces to
  `stats::rbinom(length(X), 1, 0.5)` — same draw count, same distribution, same
  position in the stream. Verified **empirically**, not by reading: for all four
  DGPs at this study's rep-1 `data_seed`s, at n = 10,000, the old and new functions
  returned `identical()` data frames (max |diff| 0 on X/A/S/Y) **and** left
  `.Random.seed` identical afterwards, so the downstream `mcmc_seed` stream is also
  unaffected.

So on code grounds the 236 partials were reproducible under HEAD.

### Axis 2 — build provenance: FAILS. This is the decisive axis.

The 236 partials record `r_version = 4.5.1` (the workstation). O2 runs **R 4.4.2**,
with a different BLAS. Mixing them is forbidden by two independent rules that this
project already committed to:

* this study's own `local/combine.R` **hard-errors** on a result set that mixes
  `r_version` or `pkg_version` — *"numerics are not comparable across builds"*;
* the `setup-cluster-simulations` provenance contract: `combine.R` *"refuses a run
  that mixes them (numerics are not bit-identical across BLAS)"*.

And the mix would land in the worst possible place. The 236 partials cover only
**12 of the 36 configs** — every one of them at λ ∈ {0.010, 0.020, 0.035}, i.e.
entirely inside the **interior regime**, which is exactly the segment the study
treats as a *falsifiable check on the estimator* against the closed-form
`Corr_K(τ_S, τ_Y)`. Reusing them would have built the flat-plateau test from one R
build and the rest of the profile from another, putting a build artifact precisely
where a theory violation would be read.

**Decision: discard and run all 720 units clean under one build.** Cost is ~236
units ≈ 5.6 O2 CPU-hours — cheap relative to a provenance caveat on the figure's
load-bearing segment. `slurm/combine.R` keeps the single-build guard (extended to
`backend`), so this decision is enforced mechanically rather than by convention.

The local partials are retained on disk; `local/combine.R --allow-partial` can
still assemble them as a separate, internally-consistent artifact if wanted.

---

## 3. Sizing — from REAL on-cluster timings, never a local estimate

`canonical-validation`'s own history is the reason this is structural rather than
advisory: it sized its array from a **local** profile of 61.409 s/unit
(`canonical-validation/config/sizing.json`) and then observed **191.8–254.6 s/unit**
on O2 — a ~3.8× underestimate, in the direction that makes every task time out.
`slurm/profile_timing.R` therefore **refuses** to write sizing from a local profile
unless explicitly overridden, and the supported path is a real `sbatch` array.

### Smoke probe (real array, real nodes)

| | |
|---|---|
| run-id | `smoke-20260925-150832_b049ad1` |
| SLURM job | `54417881` (array 1-8, `--time 0-01:00:00 --mem 4G`) |
| units | 8, one per (DGP × extreme λ), rep 1 — chosen deliberately, see below |
| result | **8/8 COMPLETED, ExitCode 0:0, 0 errors**, all `converged = 1` |

Probe rows are chosen to **straddle** the grid, not taken contiguously: the
rep-filtered unit table is config-major, so tasks 1–8 sliced contiguously would all
be config 1 (dgp1 at λ = 0.01) and would size the array off one corner.

Real per-unit wall clock, slowest first:

| unit | dgp | λ | secs | M_final |
|---|---|---|---|---|
| 41 | dgp2 | 0.01 | 85.7 | 1500 |
| 1 | dgp1 | 0.01 | 85.1 | 1500 |
| 81 | dgp4 | 0.01 | 68.4 | 1200 |
| 1281 | dgp1 | 0.30 | 68.2 | 1200 |
| 121 | dgp5 | 0.01 | 68.1 | 1200 |
| 1321 | dgp2 | 0.30 | 66.6 | 1200 |
| 1401 | dgp5 | 0.30 | 66.3 | 1200 |
| 1361 | dgp4 | 0.30 | 66.2 | 1200 |

**median 68.1 s · q0.9 85.2 s · max 85.7 s · n = 8 · 0 failures**

Worth recording because it contradicts the prior: O2 here is **~1.5× local**
(local dgp5 λ=0.01 was 45.4 s vs 68.1 s on O2), **not** the 3.8× `canonical-validation`
saw. The point stands either way — the ratio was measured, not assumed.

### Arithmetic (`slurm/profile_timing.R`, `--target-hours 1`)

Sizing uses the **q0.9 = 85.2 s/unit**, not the median: a task's wall time is the
*sum* of its block, so the expensive tail binds. λ = 0.01 costs ~25% more than
λ = 0.30 because the adaptive sampler needs M_final = 1500 there rather than 1200.

```
reps_per_job  = floor(3600 / 85.2)            = 42
total_tasks   = ceil(720 / 42)                = 18
est wall/task = 42 * 85.2 = 3578 s            = 0.99 hr
--time        = ceil(3578 * 1.5)  = 5371 s    = 0-01:29:31   (1.5x safety, as canonical-validation)
--mem         = 2G
```

`--target-hours 1` (the floor of the scaffold's 1–3 hr window) rather than 2: with
only 720 units, 18 one-hour tasks run fully concurrently and finish the sweep in
roughly one task's wall time, and 18 tasks is nowhere near the ≤1000/array or
≤10000-queued caps. Both 1 and 2 hr are inside convention; 1 hr is simply the
faster compliant choice.

`--mem 2G` is the `MEM_FLOOR_GB`, not a measurement: a finished job's peak RSS is
not recoverable from its result row, so `sizing.json` records `"peak_gb": null`
honestly. It is evidence-backed rather than guessed — the local profile of this
study peaked at ~0.6 GB, matching `canonical-validation`'s measured 0.589 GB at the
same n and identical sampler settings, and that study ran 4000 units at `--mem 2G`
with no OOM. The smoke probe ran at 4G and completed.

---

## 4. The executed run

| | |
|---|---|
| run-id | `20260925-152042_b049ad1` |
| SLURM job | `54418951` (single array, tasks 1-18, `%18` concurrency) |
| git SHA (package) | `b049ad1` |
| study code hash | `2146445639` (`config/grid.R`, `R/cell_cates.R`, `R/dgp.R`, `R/estimators.R`, `R/run_one.R`) |
| submitted | 2026-09-25 15:20:42 ET |
| rep scope | **reps 1–20** of the `TOTAL_REPS = 40` declared in `config/grid.R` |
| units | **720** (36 configs × 20 reps), 42 units/task × 18 tasks |
| resources | `--time 0-01:29:31  --mem 2G` |
| backend | O2 `short` partition, R 4.4.2, gcc/14.2.0, surrogateTransportability 0.4.0 |
| scratch | `/n/scratch/users/d/dma12/surrogate-transportability/lambda-sweep/20260925-152042_b049ad1` |
| logs | same, `/logs` (also `./logs/latest`) |

Reps 21–40 remain a deliberate, cheap future extension (seeds depend only on
`(dgp, rep)` and `(config_id, rep)`), **not** part of this run.

### Rep scoping — the one structural difference from canonical-validation

`canonical-validation` runs *all* of `unit_table()`, so a task can slice by absolute
unit id. This study cannot: `TOTAL_REPS = 40` is declared but reps 1–20 are
executed, and `unit_table()` enumerates rep-fastest within config, so reps 1–20 are
**not a contiguous unit range** — they are 36 interleaved blocks of 20, spanning
unit ids 1…1420. Slicing by absolute unit id would have silently run reps 21–40 and
under-covered reps 1–20.

So `slurm/run_replication.R` slices the **row index of the rep-filtered** table and
names partials by the true global `unit` id. Verified before any cluster time was
spent, by `slurm/validate_mapping.R` (run both locally and on O2): for
`reps_per_job` ∈ {1, 3, 5, 7, 12, 20, 37, 60, 100, 720} the tasks cover the 720
in-scope units **exactly once each**, with no duplicates and nothing out of scope.

Because the task→unit map depends on `(GRID, TOTAL_REPS, REP_FROM, REP_TO)`,
`submit.sh` records `REP_FROM/REP_TO/TOTAL_UNITS/REPS_PER_JOB/TOTAL_TASKS` in the
scratch dir's `REP_SCOPE` file, and `combine.R` refuses to assert coverage against
a scope that disagrees with it. `retry_failed.sh` resumes from `REP_SCOPE` too, not
from a possibly re-profiled `sizing.env`.

---

## 5. Current status — COMPLETE

| | |
|---|---|
| SLURM array tasks | **18/18 COMPLETED**, ExitCode 0:0 |
| unit partials | **720/720** |
| combined | `results/20260925-152042_b049ad1_reps20.rds` (720 rows × 24 cols) at 16:52 ET |
| failed replications (`error_msg`) | **0** |
| non-converged (hit `M_max`) | **0** |
| units per (DGP × λ) cell | 20 everywhere — exact, no cell short |
| wall clock | 15:20:42 → ~16:50 ET (~1 h 30 m from submission, 18 tasks concurrent) |
| total compute | **16.6 CPU-hours** (matches the README's ≈16 CPU-h estimate) |
| timeouts / SIGTERM sentinels | 0 |
| nonzero-exit sentinels | 0 |

`slurm/combine.R` passed every guard: code hash matched (`2146445639`), `REP_SCOPE`
agreed with `config/sizing.env`, 720 units covered exactly once with nothing
out-of-scope, and the single-build check reported one build throughout —
`backend o2_slurm | R 4.4.2 | surrogateTransportability 0.4.0 | git b049ad1`.

### Progress log (observed, not projected)

| time (ET) | elapsed | task files | unit partials | failures |
|---|---|---|---|---|
| 15:20 | 0 m | 0/18 | 0/720 | 0 — 18 tasks submitted (job `54418951`) |
| 15:27 | 4.5 m | 0/18 | 53/720 | 0 — all 18 RUNNING |
| 15:46 | 26 m | 1/18 | 292/720 | 0 |
| 15:59 | 38 m | 1/18 | 447/720 | 0 |
| 16:25 | 65 m | 12/18 | 701/720 | 0 |
| 16:52 | 92 m | **18/18** | **720/720** | **0** — combined |

### The 1.5× safety factor earned its keep

Over the full 720 units the per-unit tail was materially heavier than the 8-unit
smoke probe suggested:

| | smoke (n=8) | full run (n=720) |
|---|---|---|
| median | 68.1 s | 67.2 s |
| q0.9 | 85.2 s | **118.5 s** |
| max | 85.7 s | **269.2 s** |

The median was predicted almost exactly (68.1 → 67.2 s), but the q0.9 the sizing was
built on was **~1.4× low** and the max ~3.1× low — node contention and the
adaptive sampler occasionally running to a larger `M_final`. Sizing on q0.9 = 85.2 s
gave an estimated 0.99 hr/task; the `--time 0-01:29:31` that the 1.5× factor bought
is what kept all 18 tasks inside the wall clock. Had `--time` been set at the bare
estimate, tasks in the heavy tail would have timed out. **Do not drop TIME_SAFETY,
and do not size a larger `reps_per_job` off a small probe's q0.9 without it.** (A
timeout would have been recoverable, not fatal — per-unit checkpointing plus
`retry_failed.sh` — but it would have cost another cluster round trip.)

### Remaining follow-up (analysis, not infrastructure)

```bash
# the figure this study exists for; reads results/*_reps20.rds automatically
Rscript R/plot_lambda_profile.R
bash slurm/clean.sh            # on O2: drop the smoke scratch + combined run
```

The combined `.rds` has been pulled back to `results/` locally (34 KB). One
observation for whoever runs the analysis, recorded without interpretation: the
interior-regime plateau (λ ≤ 0.05) came in at mean Θ̂ ≈ 0.611 for dgp1 and ≈ −0.839
for dgp2, against the closed-form `Corr_K` values 0.645497 and −0.860663 that
`R/cell_cates.R` computes, while the λ = 0.30 column reached 0.660 / −0.867 against
the package references 0.6907 / −0.8845. The profile is flat inside the interior and
rises past it for dgp1 — the direction `R/exit_interior_prediction.R` predicted Θ
would **fall**. That is a scientific finding for the analysis pass to adjudicate,
not an infrastructure defect: coverage, seeds, and build provenance all check out.

---

## 6. Files added by this migration

```
config/sizing.env                sizing consumed by submit.sh (incl. REP_FROM/REP_TO)
config/sizing.json               human-readable sizing record + the 8 real probe timings
slurm/_code_hash.R               THE single definition of the study code hash (+ CLI)
slurm/array.slurm                SLURM array job: module bootstrap, SIGTERM trap, exit codes
slurm/submit.sh                  preflight, run-id, GRID_HASH + REP_SCOPE, chunked arrays, --smoke
slurm/run_replication.R          one task's block of REP-SCOPED units, per-unit checkpointing
slurm/profile_timing.R           sizing from a REAL O2 smoke run (refuses local by default)
slurm/combine.R                  stale-code + rep-scope + coverage + single-build guards
slurm/monitor.sh                 progress, observed per-unit secs, failure sentinels
slurm/retry_failed.sh            resume an existing run-id with bumped resources
slurm/purge_failed_tasks.R       delete poisoned task/unit files so a retry regenerates them
slurm/clean.sh                   remove superseded scratch runs
slurm/validate_mapping.R         proves the rep-scoped task->unit mapping covers 720 exactly
```

One deliberate divergence from `canonical-validation`: its `retry_failed.sh` reads
`config/sizing.tsv` + `config/sizing_totals.env` (the per-stratum scaffold form),
but that study only ever wrote `config/sizing.env` (the single-stratum form the rest
of its own scripts use) — so as shipped it could not have run. lambda-sweep is
single-cost-stratum too, so its `retry_failed.sh` reads `sizing.env`, consistent
with its own `submit.sh`.
