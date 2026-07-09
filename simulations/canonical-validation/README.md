# canonical-validation study

Validates coverage of the **fixed** canonical across-study correlation estimator
`tv_ball_correlation_IF_adaptive()` (Phase 1.5 fixes: uniform TV-ball sampler +
corrected influence-function variance) across the four canonical DGPs, at the
paper's large-n setting. This confirms the Table 2 coverage numbers that were
produced by the pre-fix estimator and are therefore suspect.

## Design

- **DGPs:** `dgp1, dgp2, dgp4, dgp5` from `canonical_dgp_params()` in the
  `surrogateTransportability` package (single source of truth; slides label
  these DGP 1-4). `dgp5` is the stress regime (PTE undefined, Delta_Y(P0) ~ 0).
- **n:** 10,000 (large-n: isolate bias, not variance).
- **reps:** 1000 per DGP -> 4000 total work units.
- **lambda:** 0.3 (TV ball). **method:** importance_weighting (RCT path).
- **Truth:** `rho_true` from the package spec (verified analytically):
  dgp1 0.691, dgp2 -0.884, dgp4/dgp5 ~1.000.

## Science files (edited from the template)

- `config/grid.R` — the 4-DGP x 1000-rep grid, seeds, unit table.
- `R/dgp.R` — thin wrapper over the package `generate_dgp_data` (no inline copy).
- `R/estimators.R` — the fixed `tv_ball_correlation_IF_adaptive` estimator + true rho.
- `R/run_one.R` — one (config, rep) unit -> one-row result.

## Run (see ../README_O2.md and ../TRANSFER.md)

```bash
# Profile to size the array. Run LOCALLY, or on an O2 INTERACTIVE node -- NOT on
# the login node (each unit is ~20-40s at n=1e4; the login node's CPU/mem cap
# SIGKILLs it: "zsh: terminated" with no R error). From the study dir use
# --study-dir . (the script defaults to .. for when it is run from slurm/).
cd simulations/canonical-validation
Rscript slurm/profile_timing.R --study-dir . --target-hours 2

# On O2, if profiling there: grab an interactive node first, e.g.
#   srun --pty -p interactive -t 0-01:00 --mem=8G -c 1 bash
#   module load gcc/14.2.0 R/4.4.2

# then submit the array (safe on the login node -- sbatch only queues):
bash slurm/submit.sh
bash slurm/monitor.sh
Rscript slurm/combine.R --run-id <id> --scratch-dir <scratch> --study-dir .
```

**Note:** the package must be installed on O2 BEFORE running anything
(`R CMD INSTALL .` from the repo root after `git pull`), since the scripts use
`library(surrogateTransportability)` (module R has no devtools). Confirm the
installed build is current with:
`Rscript -e 'library(surrogateTransportability); packageVersion("surrogateTransportability"); exists("canonical_dgp_params")'`
(expect 0.4.0 and TRUE). Local smoke test (n=400) confirmed all four DGPs run,
converge, and cover.
