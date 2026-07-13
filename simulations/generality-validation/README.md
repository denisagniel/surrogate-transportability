# generality-validation

Cluster simulation study establishing that the canonical TV-ball correlation
estimator (`tv_ball_correlation_IF_adaptive`) works **in general** — not on a few
hand-picked DGPs — and evaluating a **jackknife bias correction** for the mild
finite-n attenuation.

**Wave 1 (this study):** `importance_weighting` (RCT) path only.
**Wave 2 (deferred):** fit-once cross-fitted AIPW (Mode 1) for the observational
path. Machinery (`crossfit_once`) prototyped in
`explorations/2026-07-13_generality-pilot/`.

## Design (three blocks)

1. **Ensemble (headline)** — a rho-BALANCED set of random DGPs
   (`draw_random_dgp`, RCT-only) at n=10000, plus a subset across an n-grid.
   Random DGPs span support size K∈{3,5,8}, error laws (Gaussian / t / hetero),
   p_X concentration, and nonlinear effect modification. Report the DISTRIBUTION
   of coverage/bias across DGPs. Balanced seeds (`config/ensemble_seeds.rds`)
   flatten rho across [-1,1] so the ensemble stresses the estimator instead of
   piling up at the easy |rho|~1 boundary.
2. **Structural anchors** — the 4 canonical DGPs (incl. dgp5 stress) at n=10000.
3. **n-scaling slice** — dgp1 anchor across n∈{500,2000,10000,40000}, to document
   the finite-n attenuation and the jackknife's effect (bias vanishes ~sqrt(n)).

Every unit reports BOTH the raw estimate and the jackknife-corrected estimate
(+ CIs), so the paper's raw-vs-corrected comparison comes from one run.

## Exact truth (no noisy reference run)

The estimand `Theta = cor_mu(Delta_S(Q), Delta_Y(Q))` with
`Delta(Q) = sum_k q_k tau(k)` over finite X-support depends only on the cell
CATEs, NOT the error law. So `true_rho()` (`R/true_rho.R`) computes rho_true
EXACTLY for any DGP at high M_ref. Validated in Phase 0 against the canonical
CATEs (500k-sample empirical match).

## Workflow

```bash
# 0. Build the package (once) so library(surrogateTransportability) works on O2.

# 1. OFFLINE PREP on O2 (NOT the login node — use an interactive/batch node).
#    Balanced seeds + exact truth table. Slow (many high-M MCMC truths).
Rscript slurm/prep_offline.R --study-dir . --scan 8000:8800 --per-bin 7 --m-ref 100000
#    -> writes config/ensemble_seeds.rds and config/truth_table.rds

# 2. Profile to size the array (worst-case per-config sizing; fixes the
#    median-sizing timeout that hit canonical-validation).
Rscript slurm/profile_timing.R --study-dir . --n-units 24

# 3. Submit (chunked, throttled waves).
bash slurm/submit.sh

# 4. Monitor / combine.
bash slurm/monitor.sh
Rscript slurm/combine.R --run-id <RID> --scratch-dir <SCRATCH> --study-dir .
```

## Files

- `config/grid.R` — GRID (3 blocks), unit_table(), truth-table build, ensemble seeds.
- `R/random_dgp.R` — `draw_random_dgp`, `generate_random_data`, `build_balanced_seeds`.
- `R/true_rho.R` — exact `true_rho_from_cates`, `canonical_cates`.
- `R/dgp.R` — dispatch canonical vs random.
- `R/estimators.R` — IW estimate + VECTORIZED grouped jackknife (raw + corrected).
- `R/run_one.R` — one unit -> one row (raw + jackknife columns).
- `slurm/prep_offline.R` — one-time balanced-seeds + truth-table build.
- `slurm/{profile_timing,submit,array,run_replication,monitor,combine,clean}.*` —
  standard cluster scaffolding (profiler patched for worst-case sizing).

## Phase 0 provenance

Estimator behavior (finite-n attenuation, fit-once AIPW validity), the exact-truth
machinery, and the jackknife correction were validated locally in
`explorations/2026-07-13_generality-pilot/`. Key result: jackknife HALVES bias at
n=2000 (26/30 ensemble DGPs improved) and is HARMLESS at n=10000. See
`quality_reports/session_logs/2026-07-13_generality-study-phase0.md` and
`quality_reports/plans/2026-07-13_bias-coverage-expansion-study.md`.
