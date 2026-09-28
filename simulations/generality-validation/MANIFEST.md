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
| `20260928-141420_1188e58` | 49500 (in progress) | Submitted 2026-09-28 14:14 ET. See below. |

### Submitted: `20260928-141420_1188e58` (2026-09-28, in progress)

| Field | Value |
|---|---|
| Run id | `20260928-141420_1188e58` |
| Job | `54664735` (single array, 107 tasks, 463 units/task) |
| Units | 49500 (99 configs × 500 reps) |
| Scratch dir | `/n/scratch/users/d/dma12/surrogate-transportability/generality-validation/20260928-141420_1188e58` |
| --time / --mem | 0-02:59:42 / 3G per task (worst-case sizing; most tasks will finish well under this) |
| Requested concurrency | `%1000` (all 107 tasks eligible to run at once) |
| **Observed real concurrency** | **`%10`** — SLURM/O2 capped it far below what was requested. Traced to a shared group-level TRES budget (`GrpTRES=cpu=2000,...` on the `normand_s...` account via `sacctmgr show assoc`), not a bug in `submit.sh`/`sizing.env` (both correctly requested `%107`). Likely fluctuates with how busy the lab group's shared allocation is, not a fixed hard cap. |
| Revised time estimate | With ≤10 concurrent tasks and up to ~3hr worst-case each, total wall time could range from a few hours (if most tasks run near the observed mean cost, ~3.3s/unit) to over a day (if many tasks hit the worst-case ~15.5s/unit). Genuinely uncertain until observed; not treated as a failure mode, just a much longer horizon than confounded-aipw's runs. |
| Status | Running as of 2026-09-28 14:14 ET. Not yet confirmed complete — do not assume completion without checking `sacct`/partials count (49500 expected) directly, per this project's own hard-learned lesson about undocumented submission states across session boundaries. |

Resume: `bash slurm/monitor.sh`, then once `sacct` shows the array COMPLETED and
`find <scratch>/partials -name "*.rds" | wc -l` reads 49500,
`Rscript slurm/combine.R --run-id 20260928-141420_1188e58 --scratch-dir <scratch dir above> --study-dir .`,
then an analysis script (this study has no `analyze.R` yet — unlike
confounded-aipw — writing one is a follow-up task once results exist).
