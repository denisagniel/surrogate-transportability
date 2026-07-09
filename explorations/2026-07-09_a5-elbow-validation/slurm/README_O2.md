# O2 deployment — A5-elbow-validation (Stage 1)

SLURM infrastructure for the Stage 1 elbow-signature study on Harvard O2. Mirrors
`simulations/canonical-validation/slurm/` (chunked/throttled arrays, idempotent
tasks, stale-code hash guard, loud-failure combine).

## What runs

- **Simulation function:** `run_one_stage1(unit_row)` (in `R/run_one_stage1.R`) —
  generates one continuous-X dataset, runs the one-step cross-fit debiased
  bilinear-functional estimator AND the naive plug-in, returns a 2-row data.frame
  (one per estimator) scored against the closed-form truth.
- **Grid:** `STAGE1_GRID` in `config/grid.R` — 5 designs (A_above, D2_above,
  E_edge, G_gap, B_below) × 6 sample sizes {500,…,16000} × 3 functional pairs
  {SY, SS, YY} = 90 configs. `REPS_STAGE1 = 1000` → **90,000 work units**.
- **No project package** and no extra CRAN packages: Stage 1 is base R + stats
  only. (grf/ranger enter in Stage 2.)

## Sizing (`config/sizing.env`)

Written directly from local per-unit timings (n=500 ~0.05s … n=16000 ~2s; mean
~0.55s), NOT from `profile_timing.R` (that profiler is available but was skipped
to avoid loading the dev laptop). 90,000 units ≈ 14 CPU-hours.

- `REPS_PER_JOB=1500` → `TOTAL_TASKS=60`, ~14 min/task avg (worst-case block of
  n=16000 units ~50 min; `WALLTIME=1:30:00` gives 2× headroom).
- One array (60 ≤ 1000), no waves. `MEM_GB=4`.

To re-profile on O2 instead: `Rscript slurm/profile_timing.R --study-dir "$(pwd)"`.

## Deploy

```bash
# 0. from the repo root, push the branch with this study
git add -A && git commit -m "A5-elbow Stage 1 + O2 infra" && git push

# 1. on O2
git pull
cd explorations/2026-07-09_a5-elbow-validation

# 2. quick single-task smoke test (one task, few units, ~seconds)
STUDY_DIR="$(pwd)"; SCRATCH=/tmp/a5_test; mkdir -p "$SCRATCH"
module load gcc/14.2.0 R/4.4.2
Rscript slurm/run_replication.R --task-id 1 --reps-per-job 5 \
  --study-dir "$STUDY_DIR" --scratch-dir "$SCRATCH"
# inspect: readRDS("/tmp/a5_test/task_000001.rds") should have 10 rows

# 3. submit the full array (reads config/sizing.env, mints a run-id)
bash slurm/submit.sh

# 4. monitor
bash slurm/monitor.sh                 # progress + failed-task scan
bash slurm/monitor.sh --tail-failures # tails of any failed task logs

# 5. combine when all 60 tasks are done (run-id printed by submit.sh)
Rscript slurm/combine.R --run-id <RUN_ID> \
  --scratch-dir /n/scratch/users/d/dma12/surrogate-transportability/a5-elbow-validation/<RUN_ID> \
  --study-dir "$(pwd)"
# writes output/<RUN_ID>.rds (the one home artifact)

# 6. clean superseded scratch runs when satisfied
bash slurm/clean.sh
```

## Identity / paths (edit if your account differs)

- `HMS_ID=dma12` (in submit.sh, monitor.sh, clean.sh)
- Scratch root: `/n/scratch/users/d/dma12/surrogate-transportability/a5-elbow-validation/`
- Modules: `gcc/14.2.0`, `R/4.4.2` (array.slurm falls back to bare `gcc`/`R`).

## Analysis

`output/<RUN_ID>.rds` has one row per (unit, estimator) with columns
`design,d,s_S,s_Y,regime,n,pair,estimator,estimate,std_error,ci_lower,ci_upper,
truth,error,covered`. Feed it to `scripts/03_elbow_signature.R`'s summary block
(swap the local `mclapply` results for the combined rds) and `scripts/05_figures.R`
for the elbow-scaling and coverage figures.
