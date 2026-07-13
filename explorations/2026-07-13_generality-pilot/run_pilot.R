#!/usr/bin/env Rscript
# =============================================================================
# run_pilot.R -- Phase 0 pilot for the generality-validation study
# =============================================================================
# Reproducible driver that ties together the three pilot components and emits a
# timing/sizing table + trend data used to size the cluster run. NOT the cluster
# study itself (that is Phase 1). Run locally from the repo root:
#   Rscript explorations/2026-07-13_generality-pilot/run_pilot.R
#
# Components validated here:
#   1. true_rho()      -- exact estimand via Delta(Q)=sum_k q_k tau(k)
#   2. crossfit_once() -- fit-once AIPW nuisances (Mode 1), the feasibility win
#   3. draw_random_dgp -- random DGP ensemble spanning the assumption class
# =============================================================================

suppressWarnings(suppressPackageStartupMessages({
  library(surrogateTransportability); library(mgcv); library(ranger)
}))

PILOT_DIR <- "explorations/2026-07-13_generality-pilot"
source("simulations/canonical-validation/R/dgp.R")
source(file.path(PILOT_DIR, "R/true_rho.R"))
source(file.path(PILOT_DIR, "R/crossfit_once.R"))
source(file.path(PILOT_DIR, "R/random_dgp.R"))

# Shared estimator settings (match canonical-validation .EST_SETTINGS).
EST <- list(M_start=500, M_increment=300, M_max=2000, tolerance=0.01,
            n_stable=3, burn_in=500, thin=5, alpha=0.05)

# Run one AIPW rep with fit-once nuisances; returns rho, se, ci, covered, secs.
run_aipw_once <- function(data, truth, learner="linear", seed=1) {
  cf <- crossfit_once(data, learner, learner, n_folds=5, seed=seed)
  t <- system.time(m <- tv_ball_correlation_IF_adaptive(
    data=data, lambda=0.3, method="aipw",
    e_hat=cf$e_hat, mu_1_S=cf$mu_1_S, mu_0_S=cf$mu_0_S,
    mu_1_Y=cf$mu_1_Y, mu_0_Y=cf$mu_0_Y,
    M_start=EST$M_start, M_increment=EST$M_increment, M_max=EST$M_max,
    tolerance=EST$tolerance, n_stable=EST$n_stable, burn_in=EST$burn_in,
    thin=EST$thin, alpha=EST$alpha, verbose=FALSE))
  data.frame(rho=m$rho_hat, se=m$se,
             covered=as.integer(truth>=m$ci_lower & truth<=m$ci_upper),
             M_final=m$M_final, secs=unname(t["elapsed"]))
}

# Run one IW rep.
run_iw_once <- function(data, truth) {
  t <- system.time(m <- tv_ball_correlation_IF_adaptive(
    data=data, lambda=0.3, method="importance_weighting",
    M_start=EST$M_start, M_increment=EST$M_increment, M_max=EST$M_max,
    tolerance=EST$tolerance, n_stable=EST$n_stable, burn_in=EST$burn_in,
    thin=EST$thin, alpha=EST$alpha, verbose=FALSE))
  data.frame(rho=m$rho_hat, se=m$se,
             covered=as.integer(truth>=m$ci_lower & truth<=m$ci_upper),
             M_final=m$M_final, secs=unname(t["elapsed"]))
}

# Left intentionally as a library of helpers; specific pilot experiments are run
# from the companion scripts (nscale, ensemble) so each can be timed/cached
# independently. See session log 2026-07-13_generality-study-phase0.md.
cat("pilot helpers loaded: run_aipw_once(), run_iw_once()\n")
