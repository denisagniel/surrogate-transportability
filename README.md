# Surrogate Transportability

An R package and research project for **evaluating surrogate transportability from
a single study**. Rather than assuming that a surrogate--outcome relationship
observed in the current study will hold in future studies, the method makes that
transportability an explicit, estimable quantity.

## Method

Future studies are modeled as random probability measures drawn **uniformly from a
total-variation ball** around the observed study distribution,
`Q ~ Uniform(U(P₀, λ; TV))`, under absolute continuity `Q ≪ P₀`. The primary
estimand is the **correlation of treatment effects across studies**,

```
Θ(λ) = cor_μ( Δ_S(Q), Δ_Y(Q) ),
```

where `Δ_S(Q)`, `Δ_Y(Q)` are the treatment effects on surrogate and outcome in a
future study `Q`. High correlation means the surrogate transports well; low or
negative correlation means it does not.

Estimation, from a single study:

1. Sample `Q₁, …, Q_M` from the TV ball via **hit-and-run MCMC** (adaptive `M`).
2. For each `Q_m`, compute treatment effects by **importance weighting** (randomized
   trials) or **cross-fitted AIPW** (observational studies).
3. Estimate `Θ` as the correlation of the `M` treatment-effect pairs.
4. Report an influence-function-based confidence interval (√n asymptotic normality).

This yields a future-study estimand (like meta-analysis) from a single study (like
mediation analysis), applicable to continuous surrogates. It is the canonical
method presented in `inst/presentation/slides.qmd`.

## Quick start

```r
# install
devtools::install(".")   # or devtools::load_all(".") for development
library(surrogateTransportability)

# a canonical DGP (see canonical_dgp_params() for the four paper DGPs)
spec <- canonical_dgp_params("dgp1")
data <- generate_dgp_data(1000, spec$params, spec$p_X, spec$X_levels)

# estimate the across-study correlation with a 95% CI
fit <- tv_ball_correlation_IF_adaptive(data, lambda = 0.3,
                                       method = "importance_weighting")
c(rho_hat = fit$rho_hat, se = fit$se, lo = fit$ci_lower, hi = fit$ci_upper)

# traditional comparison (proportion of treatment effect)
compute_pte(data)
```

## Key functions

| Function | Purpose |
|----------|---------|
| `tv_ball_correlation_IF_adaptive()` | The estimator: adaptive hit-and-run + IF inference; RCT or AIPW |
| `sample_tv_ball()` | Uniform hit-and-run sampler on the TV ball |
| `generate_dgp_data()`, `canonical_dgp_params()` | Canonical DGP + the four paper specifications |
| `functional_correlation()` | Correlation functional over treatment-effect pairs |
| `compute_pte()`, `compute_mediation_effects()`, `compute_within_study_correlation()` | Traditional comparison methods |

## Project structure

```
surrogate-transportability/
├── R/                         # Package code (canonical method)
├── tests/testthat/            # Unit tests
├── inst/
│   ├── paper/                 # Manuscript, asymptotic-normality proof, IF derivation
│   └── presentation/          # Canonical slides (source of truth)
├── simulations/
│   └── canonical-validation/  # O2 cluster study: 4-DGP coverage validation
├── validation/                # Local validation scripts (sampler uniformity, calibration)
└── explorations/              # Research sandbox
```

## Simulations

The coverage-validation study lives in `simulations/canonical-validation/` and runs
on the Harvard O2 cluster (see `simulations/README_O2.md` and `TRANSFER.md`): four
DGPs, `n = 10,000`, 1000 replications, validating that the influence-function
confidence intervals achieve nominal coverage.

## Dependencies

- **Imports:** stats, mgcv, ranger (the latter two for cross-fitted AIPW nuisances)
- **Suggests:** testthat, devtools, knitr, rmarkdown

## License

MIT License.

## References

Method: "Evaluating Surrogate Transportability via Local Geometric Analysis" (in
preparation). Supported by NIDDK R01DK118354.
