# confounded-aipw

Validation study for the **observational (cross-fitted AIPW)** estimation path of
`tv_ball_correlation_IF_adaptive()`, against the **randomized (importance-weighting,
"IW")** path it is meant to generalize.

The question this study answers is not "does AIPW work" in the abstract. It is the
discriminating one: **on a data-generating process where the importance-weighting
path is provably inconsistent, does AIPW recover the estimand, and does it cost
anything where importance weighting was already fine?**

## Design (three blocks)

| Block | DGPs | $n$ | Methods | What it claims |
|---|---|---|---|---|
| `agreement` | the 4 canonical randomized DGPs (`dgp1`, `dgp2`, `dgp4`, `dgp5`) | 10,000 | IW, AIPW | **Smoke test.** Both paths are consistent here, so AIPW must reproduce IW. Disagreement is an implementation bug, not a finding. |
| `confounded` | `conf1`, `conf2` (`confounded_dgp_params()`) | 10,000 | IW, AIPW | **The content.** IW converges to the propensity-tilted correlation, not the estimand; AIPW does not. |
| `smalln` | `dgp1`, `conf1` | 250 | IW, AIPW | Supports the manuscript's small-$n$ statement (`inst/paper/main.tex`, `\label{sec:sim-future}`) with an actual run. **Stress regime:** the plug-in correlation is strongly attenuated at this $n$. |

## Why the confounded DGPs are provably discriminating

Both confounded specs reuse `dgp1`'s **mean structure verbatim** and change only
treatment assignment to `A | X ~ Bernoulli(expit(e_int + e_coef * X))`. Because the
estimand

```
Theta = cor_mu(Delta_S(Q), Delta_Y(Q)),   Delta(Q) = sum_k q_k tau(k)
```

depends on the DGP only through its cell CATEs (`canonical_cates()`), and cell
CATEs are a property of the mean structure, **`rho_true` is unchanged by the
confounding**. What changes is what the importance-weighting path converges to: its
Hájek arm means do not adjust for treatment selection, so in the canonical DGP
(where the control arm has mean zero) its per-study surrogate effect converges to
the *e-tilted* effect

```
Delta_S^IW(Q) = sum_k q_k e_k tau_S(k) / sum_k q_k e_k.
```

`iw_limit_from_cates()` computes the resulting `rho_iw_limit` exactly, so the
asymptotic IW bias is known in closed form before any data is simulated — it is not
something the simulation has to discover. The simulation's job is to confirm the IW
arm lands on that limit and the AIPW arm lands on `rho_true`.

| spec | `e_coef` | `e(X)` range | `rho_true` | `rho_iw_limit` | asymptotic IW bias |
|---|---|---|---|---|---|
| `conf1` | 0.8 | [0.168, 0.832] | 0.6876 | 0.0773 | **−0.610** |
| `conf2` | 1.6 | [0.039, 0.961] | 0.6876 | −0.4709 | **−1.159** (sign reversal) |

`conf1` keeps positivity comfortably interior, so it isolates confounding from
positivity. `conf2` is the **positivity stress** cell: the rarest covariate cell
(`p_X = 0.05`) is also nearly untreated, close to the estimator's 0.01/0.99
propensity clip. AIPW is expected to degrade there relative to `conf1`, and the
results table reports the clipping rate so that degradation is attributable rather
than mysterious.

The `e_coef` values were selected from the propensity-strength scan in
`explorations/2026-09-24_confounded-aipw-arm/R/01_design_confounded_dgp.R`.

## Fit-once cross-fitting

`crossfit_nuisances_once()` fits the five AIPW nuisances once per replication on the
observed sample and passes them through the estimator's external-nuisance mode.
Under X-transportability the nuisances are properties of `P0` and do not depend on
the sampled future study `Q` — only the importance weights do — so this is exact,
not an approximation. It also removes a factor of `M` from the cost; the estimator's
internal cross-fitting mode refits per `Q`-draw and is not viable at `M = 1500`.

## Workflow

This study runs on the **Harvard O2 SLURM cluster**, under its own scaffold in
`slurm/`. It was originally designed local-only on the grounds that ~70 minutes on
five cores made a cluster round-trip not worth a Duo approval; that argument was
revisited on 2026-09-26 and the study was migrated (see `MANIFEST.md` §1). The
science files are **unchanged** by the migration — `run_one()` already kept the
cluster contract — and `run_study.R` / `analyze.R` still work, so the local path
remains available. The O2 path is additive.

Because per-unit cost differs by ~2 orders of magnitude between the $n = 10{,}000$
blocks and the $n = 250$ block, `config/grid.R`'s `stratum_of()` splits the study
into two cost strata (`large_n`, `small_n`) that are **sized and submitted
separately**. See `MANIFEST.md` for the real measured per-stratum timings.

```bash
# --- O2 (from simulations/confounded-aipw on the cluster) -------------------
Rscript slurm/validate_mapping.R .        # prove the task->unit map, BEFORE submitting
bash slurm/submit.sh --smoke              # real per-stratum timing probes (16 units)
Rscript slurm/profile_timing.R --study-dir . \
  --from-smoke-dir <smoke scratch> --target-hours 1
bash slurm/submit.sh                      # the full 1120-unit run, one array per stratum
bash slurm/monitor.sh                     # progress, per-stratum timings, failures
Rscript slurm/combine.R --run-id <id> --scratch-dir <scratch> --study-dir .
Rscript analyze.R --run-id <id>           # from the repository root

# --- local (still supported) ------------------------------------------------
# from the repository root; the package must be installed, not just load_all'd
Rscript -e 'devtools::install(".", quick = TRUE)'

Rscript simulations/confounded-aipw/run_study.R --smoke              # 16 units, ~1 min
Rscript simulations/confounded-aipw/run_study.R --workers 5          # full study
Rscript simulations/confounded-aipw/analyze.R                        # newest run

# a single block, e.g. after changing only the confounded specs
Rscript simulations/confounded-aipw/run_study.R --blocks confounded
```

`--smoke` (either backend) runs one replication per configuration. Its output is
**not reportable**: the local driver overrides `M_MAX`, and the O2 probe covers a
deliberately non-representative subset of cells, so `slurm/combine.R` refuses to
combine a smoke scratch dir into `results/` at all.

## Files

- `config/grid.R` — the three blocks, per-block replication counts, adaptive-$M$
  settings, cost strata, and the ordering-invariant per-unit seed.
- `config/sizing.tsv`, `sizing_totals.env`, `sizing.json` — per-stratum O2 sizing,
  derived from real on-cluster probe timings (never a local profile).
- `R/dgp.R` — dispatch to `canonical_dgp_params()` / `confounded_dgp_params()`; the
  estimand both arms are scored against.
- `R/estimators.R` — the two arms. Both call the same package estimator; the AIPW arm
  additionally cross-fits nuisances once and records the propensity clipping count.
- `R/run_one.R` — one unit → one row, including `error` (distance from the estimand)
  and `error_vs_iw_limit` (distance from the importance-weighting limit).
- `run_study.R` — local `mclapply` driver; writes `results/<run-id>.rds` with
  provenance attributes and asserts exactly-once unit coverage.
- `slurm/` — the O2 scaffold: per-stratum arrays, per-unit checkpointing and
  resume, stale-code and single-build guards, and `validate_mapping.R`, which
  proves the task→unit mapping before any cluster time is spent. `combine.R`
  writes `results/<run-id>.rds` with the same attributes `run_study.R` sets, so
  `analyze.R` consumes either backend's output unchanged.
- `analyze.R` — per-configuration summary plus the paired IW-vs-AIPW contrast;
  writes `results/<run-id>_summary.rds`.

## Package dependencies introduced for this study

- `confounded_dgp_params()`, and `generate_dgp_data()`'s `e_int`/`e_coef` arguments
  (`R/dgp_canonical.R`)
- `canonical_cates()`, `true_rho_from_cates()`, `iw_limit_from_cates()`
  (`R/true_rho.R`)
- `crossfit_nuisances_once()` (`R/crossfit_nuisances.R`)

Tested in `tests/testthat/test-dgp-confounded.R` and
`tests/testthat/test-crossfit-nuisances.R`.
