---
name: canonical-method-spec
description: The canonical definition of the surrogate-transportability method (from the May 2026 slides), the source of truth for realignment
metadata:
  type: project
---

As of 2026-07-08, the **canonical** surrogate-transportability method is defined by `inst/presentation/slides.qmd` (dated May 12, 2026). Everything else (package, `inst/paper/main.tex`, sims, MEMORY.md) had drifted and is being realigned to it.

**Canonical method:** future studies as random measures `Q ~ Uniform(U(P₀, λ; d))`; **total variation** ball, λ=0.3; **absolute continuity** Q≪P₀, finite support; **hit-and-run MCMC** (adaptive M≈2100); per-Q treatment effects via **importance weights** (RCT) or **cross-fitted AIPW** (observational); estimand = **correlation of (ΔS, ΔY) across future studies** (R²/MSPE are secondary examples only); inference = two-stage **influence-function / functional delta method**, √n asymptotic normality. Validation = **4 DGPs**, linear, single 5-level categorical X, n=10,000, plus the **PTE-misleading example** (PTE=0.54, cor=0.00).

**NOT canonical (slated for deletion):** minimax/Wasserstein DRO family, Bayesian/Dirichlet `posterior_inference` (the old `Q=(1−λ)P₀+λP̃` mixture model), concordance/PPV/NPV/conditional-mean/CATE functionals, observation-level minimax, ε-close grid-search inference, RF-ensemble approximation theorem, "classification" Study 1.

**Canonical live entry points:** `tv_ball_correlation_IF_adaptive` (THE estimator), `generate_dgp_data` (the DGP — currently defined inline in scripts, NOT yet a package export; must be promoted), `compute_pte` (comparison only).

Full plan: `quality_reports/plans/2026-07-08_canonical-realignment-master-plan.md`. See [[realignment-decisions]].
