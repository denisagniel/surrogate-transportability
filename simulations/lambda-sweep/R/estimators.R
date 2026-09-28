# =============================================================================
# estimators.R -- estimator for the "lambda-sweep" study
# =============================================================================
# One estimator, and it is DELIBERATELY UNTOUCHED: the canonical across-study
# correlation estimator tv_ball_correlation_IF_adaptive() from the
# surrogateTransportability package, called through the importance_weighting
# (RCT) path. This study varies ONLY lambda; the estimator, the sampler
# (sample_tv_ball), and every tuning constant below are byte-identical to
# simulations/canonical-validation/R/estimators.R so that this study's
# lambda = 0.3 column is directly comparable to the paper's Table 2.
# =============================================================================

# Shared estimation settings -- IDENTICAL to canonical-validation. Do not retune
# them to make the sweep cheaper: a sweep run under different sampler settings
# is not comparable to Table 2, which is half the value of the figure.
.EST_SETTINGS <- list(
  M_start     = 300L,
  M_increment = 300L,
  M_max       = 5000L,
  tolerance   = 0.01,
  n_stable    = 3L,
  burn_in     = 500L,
  thin        = 5L,
  alpha       = 0.05
)

estimate <- function(data, config) {
  switch(
    config$method,
    importance_weighting = .est_tv_ball(data, config),
    stop(sprintf("Unknown method: '%s'", config$method))  # no silent fallback
  )
}

# --- Canonical TV-ball adaptive correlation estimator (UNMODIFIED) ------------
.est_tv_ball <- function(data, config) {
  s <- .EST_SETTINGS
  res <- tv_ball_correlation_IF_adaptive(
    data        = data,
    lambda      = config$lambda,
    method      = config$method,
    M_start     = s$M_start,
    M_increment = s$M_increment,
    M_max       = s$M_max,
    tolerance   = s$tolerance,
    n_stable    = s$n_stable,
    burn_in     = s$burn_in,
    thin        = s$thin,
    alpha       = s$alpha,
    verbose     = FALSE
  )
  list(
    estimate  = res$rho_hat,
    std_error = res$se,
    ci_lower  = res$ci_lower,
    ci_upper  = res$ci_upper,
    M_final   = res$M_final,
    converged = isTRUE(res$converged)
  )
}

# -----------------------------------------------------------------------------
# true_value() -- the reference value of Theta(P_0, lambda), WHERE ONE EXISTS.
#
# This is the one place where a lambda sweep cannot reuse canonical-validation's
# code: that study ran at a single lambda (0.3) and could take the stored
# `rho_true` from canonical_dgp_params() as THE truth. Across a lambda grid,
# `rho_true` is the truth at lambda = 0.3 ONLY. Three cases, kept explicit rather
# than papered over with a single number (Constitution: no silent fallback):
#
#   lambda <= p_min   "interior_closed_form"  Theta = Corr_K(tau_S, tau_Y) exactly
#                                             (Proposition "Interior-regime
#                                             closed form"). Coverage is
#                                             meaningful here.
#   lambda == spec$lambda (0.3)
#                     "package_mc_reference"  the stored long-run hit-and-run MC
#                                             estimate rho_true (+/- ~0.001-0.005,
#                                             per canonical_dgp_params() docs).
#                                             Coverage is meaningful, up to that
#                                             MC error in the reference itself.
#   otherwise         "none"                  NO reference value exists in the
#                                             intermediate regime -- that is
#                                             precisely what the sweep measures.
#                                             Returns NA, and coverage is NA.
# -----------------------------------------------------------------------------
true_value <- function(config) {
  spec  <- canonical_dgp_params(config$dgp)
  p_min <- min(spec$p_X)

  if (config$lambda <= p_min + 1e-12) {
    return(list(truth = corr_K_cell_cates(config$dgp), source = "interior_closed_form"))
  }
  if (isTRUE(all.equal(config$lambda, spec$lambda))) {
    return(list(truth = spec$rho_true, source = "package_mc_reference"))
  }
  list(truth = NA_real_, source = "none")
}
