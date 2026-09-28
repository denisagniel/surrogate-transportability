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

**No run has completed as of 2026-09-25.** An earlier version of this file claimed a
completed run (`20260925-122056`, 1120 units, output at
`results/20260925-122056_summary.rds`); that entry was fabricated — `results/` is
empty, and the claimed filename does not even match `run_study.R`'s actual save
path (`results/<run_id>.rds`, no `_summary` suffix). No unit of this study has
been executed to completion under any run-id. This table will be filled in only
once a run's output file actually exists on disk at the stated path.

| Run id | Units | Notes |
|---|---|---|
| _(none yet)_ | — | — |

Superseded or smoke runs are not retained in `results/`.

### Submitted but unverified (not a completed run)

Recorded here so the next session does not resubmit a sweep that may already have
finished. **This is not a Runs-table entry and must not be promoted to one until a
results file exists on disk.**

| Field | Value |
|---|---|
| Run id | `20260926-092734_b049ad1` |
| Jobs | `54483375` (large_n stratum, 17 tasks), `54483376` (small_n stratum, 1 task) |
| Units intended | 1120 (`agreement` 320 + `confounded` 320 + `smalln` 480) |
| Scratch dir | `/n/scratch/users/d/dma12/surrogate-transportability/confounded-aipw/20260926-092734_b049ad1` |
| Last observation | 2026-09-26 ~14:09 ET — 18/18 tasks RUNNING, **102/1120** units written, 0 failures |
| Expected wall | ~55 min total (from the on-O2 smoke: large_n ≈ 83 s/unit, small_n ≈ 2.9 s/unit) |
| Final state | **UNKNOWN.** The orchestrating session wedged immediately after that observation (a local `childprocess-spawn` bug during an SSH rate-limit back-off, unrelated to the job), and the 2026-09-27 follow-up could not authenticate to O2 under `BatchMode`. No `sacct` confirmation, no filesystem unit count, no partials pulled back. |

Resolution steps are in `session_notes/2026-09-27.md` ("Next"). Note that
`config/sizing.tsv` / `sizing.json` are absent from this subtree: sizing was derived
from an on-O2 `submit.sh --smoke` run and those artifacts exist only on scratch, so
the committed tree pins the study code, not the array sizing.
