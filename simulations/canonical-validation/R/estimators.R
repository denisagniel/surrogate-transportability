# =============================================================================
# estimators.R -- estimator for the "canonical-validation" study
# =============================================================================
# One estimator: the FIXED canonical across-study correlation estimator
# tv_ball_correlation_IF_adaptive() from the surrogateTransportability package
# (Phase 1.5 fixes: uniform TV sampler + corrected influence-function variance).
# Returns a named list of scalars; combine.R binds these into a tidy frame.
# =============================================================================

# Shared estimation settings (match the paper's design; kept out of GRID since
# they are constant across all four DGPs).
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

# --- Fixed TV-ball adaptive correlation estimator ----------------------------
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

# The estimand (true across-study correlation) from the package spec.
true_value <- function(config) {
  canonical_dgp_params(config$dgp)$rho_true
}
