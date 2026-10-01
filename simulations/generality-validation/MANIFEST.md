# MANIFEST — generality-validation

| | |
|---|---|
| Study | `generality-validation` |
| Project | `surrogate-transportability` |
| Estimator | `surrogateTransportability::tv_ball_correlation_IF_adaptive()` + a study-local vectorized delete-block jackknife (`R/estimators.R`) |
| Wave | 1 (importance_weighting / RCT path only). AIPW (fit-once, Mode 1) is Wave 2, deferred. |

## What this study is for

Establishing that the canonical TV-ball correlation estimator works **in general**
— not on a few hand-picked DGPs — via a rho-balanced ensemble of random DGPs
(varying support size, error law, `p_X` concentration, effect-modification
shape), plus the 4 canonical DGPs as structural anchors, plus an n-scaling
slice (dgp1 anchor, n∈{500,2000,10000,40000}). Also evaluates a jackknife bias
correction for finite-n attenuation (Phase 0: halves bias at n≤2000, harmless
at n=10000). See `README.md` for full design.

## History

- **2026-07-13 to 2026-07-16:** Phase 0 validated locally (`explorations/2026-07-13_generality-pilot/`).
  Offline prep (balanced ensemble seeds + exact truth table, 99 configs) run
  on O2 and still present (`config/ensemble_seeds.rds`, `config/truth_table.rds`,
  `config/truth/*.rds` — these are O2-only scratch-derived artifacts, not
  git-tracked, same convention as confounded-aipw's `sizing.tsv`).
- **2026-07-17:** First full run (`20260717-082417_5d07c37`, 24000 rows,
  random-DGP ensemble block only) — later found INVALID.
- **2026-09-23:** RNG bug found and fixed (`f6cc5c0`): `draw_random_dgp()`'s
  internal `set.seed(dgp_seed)` clobbered the per-replication data seed
  `run_one()` had set, so every replication within a `random` config drew
  IDENTICAL data. Quarantined the 2026-07-17 result
  (`results/README.md`). Study left unrun since.
- **2026-09-28:** Relaunched. See below.

## 2026-09-28: fixes applied before relaunch

1. **RNG fix verified empirically** (not just re-read): confirmed different
   seeds now produce different data (`identical()` FALSE) while the same seed
   remains reproducible (TRUE), matching `run_one()`'s real
   `set.seed()`-then-`generate_data()` calling contract. Truth-table
   computation (`slurm/prep_truth_one.R`) is a separate, deterministic code
   path (`draw_random_dgp()` → `true_rho_from_cates()`, no simulated data
   involved) and was never affected by the bug — the existing
   `config/truth_table.rds` (99/99 configs) remains valid and was NOT
   recomputed.
2. **`M_max` lowered 5000 → 1500** (`R/estimators.R`), matching
   confounded-aipw's now-validated choice. Oracle-flagged latent OOM risk:
   the jackknife's own `M x n` weight matrix is ~1.6GB at n=40000, M=5000
   alone, on top of the several similarly-sized matrices
   `tv_ball_correlation_IF_adaptive()` itself allocates at `M_max`. Under the
   package's v0.4.1 MC-precision stopping rule, required M for adequate
   precision is independent of n and comfortably under 1500 at this study's
   observed rho range.
3. **Jackknife "shared draws" comment corrected.** `.jackknife_rho()`
   independently re-seeds (`seed_offset + config$seed %% 1e6`) rather than
   reusing the raw estimator's actual Q draws — the old comment claimed
   otherwise. Measured the practical impact on 6 canonical/n=2000 units: gap
   between the raw estimator's `rho_hat` and the jackknife's own `rho_full` is
   0.01-0.09x the raw estimator's IF SE — negligible. Code unchanged, comment
   fixed to describe reality.
4. **Added `slurm/validate_mapping.R`** (this study never had the
   confounded-aipw/lambda-sweep equivalent). Caught one real bug immediately:
   an O(n²) vector-growth anti-pattern (`c()` inside the per-task loop) that
   visibly hung on the real 49500-unit grid at `reps_per_job=1`; fixed by
   pre-allocating. Also validates the two offline-prep artifacts are present
   and that every unit has non-NA `rho_true` (an all-NA truth table would make
   every coverage number silently meaningless — the exact failure mode
   `submit.sh`'s own preflight (b) already guards, re-checked here earlier in
   the pipeline).

## Sizing methodology note

Unlike confounded-aipw/lambda-sweep, this study's `profile_timing.R` is
LOCAL-only by design (documented: "profiling on the cluster wastes an
allocation") and has no real-hardware smoke-probe step. Running it on O2's
**login node** directly hung/was killed with no output (consistent with this
project's general finding elsewhere that login nodes are unreliable for
nontrivial compute — see `simulations/TRANSFER.md`'s parallel warning against
large transfers there). Worked around by submitting `profile_timing.R`
unchanged via `sbatch --wrap=...` onto a real compute node instead of editing
the script. Ran it twice: first at the default `--n-units 24` (24/99 configs
probed, worst-case 15.16s), then at `--n-units 99` (full coverage, worst-case
15.52s) to rule out an untested config being the true worst case — the two
numbers agree closely, so the sample wasn't hiding a materially worse config.

## Runs

| Run id | Units | Notes |
|---|---|---|
| `20260717-082417_5d07c37` | 24000/24000 | **INVALID** (RNG bug — see `results/README.md`). Random-DGP ensemble block only; canonical anchors and n-scaling slice never run under this id. |
| `20260928-141420_1188e58` | 49500/49500 | **COMPLETE**, combined 2026-09-30. See below. |

### Completed: `20260928-141420_1188e58` (submitted 2026-09-28, combined 2026-09-30)

| Field | Value |
|---|---|
| Run id | `20260928-141420_1188e58` |
| Jobs | `54664735` (initial array, 107 tasks, 463 units/task) + `54918980` (4-task OOM rerun) |
| Units | 49500 (99 configs × 500 reps), all present, 0 `error_msg` rows |
| Scratch dir | `/n/scratch/users/d/dma12/surrogate-transportability/generality-validation/20260928-141420_1188e58` |
| Result | `results/20260928-141420_1188e58.rds` (49500 rows × 25 cols) |
| Summary | `results/20260928-141420_1188e58_summary.rds` (per-config, written by `analyze.R`) |
| Initial sizing | `--time 0-02:59:42 --mem 3G` per task |
| **Observed real concurrency** | **`%10`** — SLURM/O2 capped it far below the requested `%1000`. Traced to a shared group-level TRES budget (`GrpTRES=cpu=2000,...` on the `normand_s...` account via `sacctmgr show assoc`), not a bug in `submit.sh`/`sizing.env`. Likely fluctuates with how busy the lab group's shared allocation is, not a fixed hard cap. |

#### Memory undersizing: 4 tasks OOM-killed at `--mem 3G`

Array indices **92, 93, 106, 107** ended `OUT_OF_MEMORY`, each pinned at the
3 GiB cap (`MaxRSS` 3143–3145 MiB); the other 103 tasks completed. The units that
triggered the kills all lie in an **n=40000 config whose adaptive `M` reached the
`M_max = 1500` cap** — configs 86 (`rho_true = -0.552`) and 99 (dgp1 at n=40000,
`rho_true = +0.688`). (992 units went missing in total, because a task that dies
also loses the cheap units queued behind the expensive one: task 93's block
included 59 units of config 87 at n=500 that it never reached.) Peak RSS at
n=40000 is governed by `M_final x n`, not by n alone, which is why ten *other*
n=40000 configs completed comfortably:

| config | `rho_true` | median `M_final` | task peak RSS |
|---|---|---|---|
| 62, 65, 68, 71, 74, 77, 92 | $\lvert\rho\rvert \ge 0.92$ | 300 | 0.9–1.1 GiB |
| 59, 83, 89 | 0.78–0.99 | 600 | 1.8–2.1 GiB |
| 80 | 0.670 | 900 (max 1200) | **2.94 GiB** (survived by 2%) |
| 86, 99 | −0.552, 0.688 | 1500, 900–1500 | **OOM at the 3 GiB cap** |

Sized the rerun by extrapolating that scaling (~2.8 GiB per 1000 draws at
n=40000, projecting ~4.3 GiB at M=1500) rather than doubling blindly: `--mem 8G`,
`--time 0-06:00:00` (measured per-unit cost 18.4 s for config 86, so task 93's
404 remaining units need ~2 h, which the original 2:59:42 only just covered).
Measured peaks on the rerun were **3.87 / 4.09 / 3.64 / 3.26 GiB** for tasks
92 / 93 / 106 / 107 — a 4G request would still have failed on task 93.

#### Latent bug the rerun exposed: `unit_table()` resolves `config/` against the job CWD

`slurm/run_replication.R` calls `unit_table()` with no `study_dir`, so
`grid.R`'s `load_truth()` and `.ensemble_seeds()` resolve `config/*.rds`
relative to the **job's working directory**, not `opt$study_dir` (which is used
only for `source()`). The original run worked purely because `submit.sh` was
launched from the study dir. A rerun submitted from `$HOME` therefore missed
both caches: `ENS_SEEDS` silently fell back to the naive 60-seed block, so
`nrow(unit_table())` became 51500 instead of 49500 and **every task computed a
different config than its unit ids denote** (unit 42529 mapped to config 86 at
n=2000 rather than n=40000). It failed loudly at `true_value()`
("rho_true missing for this config") rather than producing plausible wrong
numbers, so all 992 rows were caught by `combine.R`'s `error_msg` report and
purged with `purge_failed_tasks.R --apply` (which removed exactly the 992
partials and 4 task files, restoring the pre-rerun state). The successful rerun
pins `sbatch --chdir="$STUDY_DIR"`.

The study source files were deliberately **not** edited to fix this, because any
change to `config/grid.R`/`R/*.R` changes the code hash `combine.R` verifies and
would have invalidated the 48508 units already on disk. Passing `study_dir`
through to `unit_table()` is the proper fix and belongs with the next
re-profiling of this study.

#### Resume/retry mechanism note

`slurm/retry_failed.sh` could not be used: it requires the per-stratum
`config/sizing.tsv` + `sizing_totals.env` that newer studies produce, whereas
this study predates cost strata and carries the single-stratum
`config/sizing.env`. The rerun therefore invoked `slurm/array.slurm` directly
with `--array=92,93,106,107` and `ARRAY_OFFSET=0` (the single stratum's offset),
which preserves the global-task-id mapping exactly and relies on
`run_replication.R`'s per-unit idempotent skip for the 819 units those four
tasks had already completed. Recorded as `~/resubmit_oom.sh` on O2.

Analysis: `Rscript simulations/generality-validation/analyze.R --run-id 20260928-141420_1188e58`
(from the repository root) writes `results/<run-id>_summary.rds` and prints the
three block reports.

