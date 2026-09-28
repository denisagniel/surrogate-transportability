# lambda-sweep study

Produces the paper's missing **λ-sensitivity figure**: $\hat\Theta_n(\lambda)$ with
influence-function-based confidence bands across a grid of TV-ball radii, for the four
canonical DGPs. This is the diagnostic promised twice in `inst/paper/main.tex` — in the
"Interpreting $\lambda$" paragraph of the Discussion ("we recommend reporting
$\hat\Theta_n(\lambda)$ across a grid: a flat profile indicates transportability that
is robust to substantial distributional shift, while a declining profile flags
fragility") and in the third bullet of §`sim-future` — and never previously run.

The estimator `tv_ball_correlation_IF_adaptive()` and the sampler `sample_tv_ball()`
are used **unchanged**, with sampler settings byte-identical to
`simulations/canonical-validation/R/estimators.R`. This study varies **only λ**.

## Design

| | |
|---|---|
| **DGPs** | `dgp1`, `dgp2`, `dgp4`, `dgp5` from `canonical_dgp_params()` (paper labels DGP 1–4). `dgp5` is the stress regime: $\Delta_Y(\PP_0)\approx0$, PTE undefined. |
| **λ grid** | `0.010, 0.020, 0.035, 0.050 | 0.070, 0.100, 0.150, 0.220, 0.300` — 4 interior points, the boundary, 5 exterior points |
| **n** | 10,000 (matches `canonical-validation` and the paper's Table 2) |
| **method** | `importance_weighting` (RCT path) |
| **reps** | `TOTAL_REPS = 40` declared; **reps 1–20 executed** (see sizing below) |
| **backend** | one workstation, `parallel::mclapply`, 8 workers, per-unit checkpointing |

### Why this λ grid, and not a safe interior one

All four canonical DGPs share $p_X=(0.05,0.25,0.40,0.25,0.05)$, so

$$p_{\min} := \min_k p_0(k) = 0.05,$$

and `inst/paper/theory.tex` shows that threshold is **sharp** (Lemma "The interior
regime requires atomic support, and the sufficient condition is sharp"). The grid
therefore straddles it deliberately:

* **λ ≤ 0.05 — interior regime.** Proposition "Interior-regime closed form" says
  $\Theta(\PP_0,\lambda) = \mathrm{Corr}_K(\tau_S,\tau_Y)$ *exactly*, independent of λ
  and of $p_0$'s composition. The profile must be **flat** here, at a value computable
  in closed form (`R/cell_cates.R`): 0.645497 (dgp1), −0.860663 (dgp2), 1 (dgp4, dgp5).
  This makes the interior segment a **falsifiable check on the estimator**, not just a
  set of safe points.
* **λ > 0.05 — outside the interior regime.** Proposition "First-order exit from the
  interior regime" predicts the *sign* of $\partial_\lambda^+\Theta$ at $\lambda=p_{\min}$
  MCMC-free, as the sign of $\sum_{k\in\mathcal K^*}\varpi(k)$ where $\varpi$ is
  (minus) the classical Pearson-correlation influence function at the smallest strata's
  standardized CATEs. `R/exit_interior_prediction.R` evaluates it before any sampling:

  | DGP | $\mathrm{Corr}_K$ | $\mathcal K^*$ | $\sum\varpi$ | prediction at λ=0.05⁺ |
  |---|---|---|---|---|
  | dgp1 | 0.645497 | x=−2, x=2 | −0.0430 | Θ **falls** |
  | dgp2 | −0.860663 | x=−2, x=2 | +0.0255 | Θ **rises** |
  | dgp4 | 1.000000 | x=−2, x=2 | 0 | flat to first order |
  | dgp5 | 1.000000 | x=−2, x=2 | 0 | flat to first order |

  (Sanity check from the proposition: $\sum_{k=1}^K\varpi(k)=0$ holds to ~1e-17.)
  This is a genuine prediction to be checked, because the *global* reference values
  point the other way: the package's stored $\rho_{\text{true}}$ at λ=0.3 is 0.6907 for
  dgp1 (**above** the interior 0.6455) and −0.8845 for dgp2 (**below** the interior
  −0.8607). If both the local slope and the global endpoint are right, both profiles
  must be **non-monotone** — which is exactly what Remark "Scope: a local result, not a
  global trajectory" warns is possible, and exactly what the grid's resolution just past
  0.05 (0.07, 0.10) is placed to see.

### Paired design (the one structural difference from `canonical-validation`)

The dataset for replication *r* of DGP *d* is the **same dataset at every λ**:
`config/grid.R` keys `data_seed` on `(dgp, rep)` only, and keys the hit-and-run
`mcmc_seed` on `(config_id, rep)` so neighbouring λ points are not additionally coupled
through common random numbers in the sampler.

Two reasons. First, fidelity: that *is* the recommended practice — one study, swept over
λ. Second, precision: replication-level sampling noise is common across λ, so the
**shape** of the profile is estimated far more precisely than its level. Measured on
replication 1: the within-study change $\hat\Theta_n(0.30)-\hat\Theta_n(0.01)$ is
+0.008 (dgp1) and −0.010 (dgp2), against a level that sits ~0.19 above truth for that
particular draw. Roughly a **14×** precision gain on the quantity the figure is about.

## Cost and sizing decision

**Profiled before running anything at scale**, as required — 8 real units at
n = 10,000 across the λ range and all four DGPs (not extrapolated from small n):

| | measured |
|---|---|
| per unit, single-threaded, uncontended | 46–86 s (dgp1 72–86 s, dgp5 47–49 s) |
| per unit, under 8-way contention | 78–89 s CPU |
| **wall throughput, 8 workers** | **8 units / 90 s ≈ 11.3 s per unit** |
| reps 1–20 → 36 configs × 20 = **720 units** | ≈ 16 CPU-h ≈ **2.2 h wall** |
| full TOTAL_REPS = 40 → 1440 units | ≈ 32 CPU-h ≈ 4.5 h wall |

**Decision: local, not O2.** Two reasons, the second decisive.

1. **Scale.** 16 CPU-hours is roughly 1/12 of `canonical-validation`'s ~200 CPU-hours.
   At that size the SLURM machinery (per-stratum sizing, ≤1000-task arrays, Duo-budgeted
   sessions, scratch/home transfer discipline) costs more human time than it saves
   compute — the `setup-cluster-simulations` scaffold targets jobs sized at 1–3 h *per
   task*, and this whole study is under one such task per 700 units of parallel width.
2. **O2 can only run what git delivers, and this track is not permitted to commit.**
   Submission would require `git push` of `simulations/lambda-sweep/` plus a package
   reinstall on the cluster; the scaffold's own `submit.sh` preflight fails on unpushed
   commits for exactly this reason (`O2_STRICT=1` exit code 4). A cluster run was
   therefore not available at all within this track's scope, independent of cost.

Crash safety is retained rather than dropped along with SLURM: each finished unit is
flushed atomically to `results/partials/<run-id>/unit_NNNNNN.rds`, so re-invoking
`run_local.R` with the same `--run-id` skips completed units, and a unit that throws
persists its error text in `error_msg` instead of a silent all-NA row.

### Precision tradeoff, stated explicitly

This study runs **20 replications, not `canonical-validation`'s 1000**, at the same
n = 10,000. Consequences, in both directions:

* **Level.** Monte-Carlo SE of the mean $\hat\Theta_n(\lambda)$ is $\mathrm{sd}/\sqrt{20}$
  ≈ **0.031** for dgp1 (empirical sd ≈ 0.14), against 0.0044 for canonical-validation's
  1000 reps. The absolute height of the dgp1/dgp2 curves is therefore coarse.
* **Shape.** Because of the paired design, the λ-contrasts the figure exists to show
  carry an MC SE roughly an order of magnitude smaller — the `lambda_contrast` panel
  reports it directly per point. The shape, not the level, is the deliverable.
* **Not a coverage study.** Coverage is reported where a reference value exists
  (interior closed form; λ = 0.3 package reference) but at R = 20 its binomial noise is
  ±0.10, so it cannot refine or replace Table 2. No reference value exists in the
  intermediate regime at all, and `true_value()` returns `NA` there rather than reusing
  the λ = 0.3 number — the intermediate values are what the sweep *measures*.
* **n was deliberately not reduced** as the cheaper lever. At n = 2000, $\hat\Theta_n$
  for dgp1 came in at 0.58 and at n = 500 at 0.37, against the interior truth 0.645:
  small-n attenuation of that size would confound the λ-shape with an n-effect.
* **Extending is cheap and safe.** Seeds depend only on `(dgp, rep)` and
  `(config_id, rep)`, so running `--rep-from 21 --rep-to 40` later strictly adds
  information without invalidating reps 1–20; `combine.R` asserts coverage of whatever
  rep range is claimed.

## Files

```
config/grid.R                    GRID (4 DGPs x 9 lambdas), seeds, unit table, LAMBDA_GRID rationale
R/cell_cates.R                   analytic cell CATEs + Corr_K closed form (shared by truth & prediction)
R/dgp.R                          thin wrapper over the package generate_dgp_data
R/estimators.R                   the UNMODIFIED estimator + lambda-aware true_value()
R/run_one.R                      one (config, rep) unit -> one-row result
R/exit_interior_prediction.R     MCMC-free first-order slope sign at lambda = p_min
R/plot_lambda_profile.R          summary tables + the two RAND-styled figures (PDF + PNG)
local/run_local.R                parallel runner: per-unit checkpoints, resumable, rep blocks
local/combine.R                  de-dup by unit, coverage assertion, provenance check
results/                         combined .rds, summary .rds/.csv, figures/, partials/, logs/
```

## Run

```bash
cd simulations/lambda-sweep

Rscript R/exit_interior_prediction.R                     # < 1 s, the falsifiable prediction
Rscript local/run_local.R --smoke                        # 8 units, ~1.5 min, plumbing check
Rscript local/run_local.R --rep-from 1 --rep-to 20       # ~2.2 h on 8 workers
Rscript local/combine.R --run-id <id> --rep-to 20
Rscript R/plot_lambda_profile.R
```

`results/figures/lambda_profile.pdf` is the vector asset for the paper;
`lambda_profile.png` is a raster preview. See `MANIFEST.md` for the executed run's
identity and observed numbers.

## Relation to the paper

Fills the λ-sensitivity promise of `inst/paper/main.tex` §`sim-future` (third bullet)
and the Discussion's "Interpreting λ" paragraph. **No manuscript file is edited by this
study**; the numbers and figure are produced here for a later manuscript pass.
