# =============================================================================
# run_one.R -- run a single work unit (one config x one replication)
# =============================================================================
# Same contract as simulations/canonical-validation/R/run_one.R: run_one() is
# pure with respect to its seeds and returns a ONE-ROW data.frame (never a list)
# so results rbind cleanly.
#
# TWO seeds, not one -- the paired design (config/grid.R):
#   data_seed  depends on (dgp, rep) ONLY -> replication r of DGP d sees the SAME
#              dataset at every lambda, so the lambda profile is a within-study
#              profile and rep-level noise is common across lambda.
#   mcmc_seed  depends on (config_id, rep) -> the hit-and-run stream is
#              independent across lambda, so neighbouring lambda points are not
#              additionally coupled through common random numbers in the sampler.
#
# `covered` is NA where no reference value exists (intermediate regime); see
# true_value() in estimators.R. `error_msg` is NA here and populated by the
# runner's tryCatch on failure, so a failed unit persists its ERROR TEXT rather
# than a silent all-NA row.
# =============================================================================

# Assumes generate_data(), estimate(), true_value(), corr_K_cell_cates() are
# already sourced (dgp.R, estimators.R, cell_cates.R).

run_one <- function(unit_row) {
  config <- unit_row  # unit_row carries all grid columns plus ids/seeds

  # 1. Dataset: keyed on (dgp, rep) so it is SHARED across the lambda grid.
  set.seed(unit_row$data_seed)
  data <- generate_data(config)

  # 2. Estimation: fresh sampler stream keyed on (config_id, rep).
  set.seed(unit_row$mcmc_seed)
  t0  <- proc.time()[["elapsed"]]
  est <- estimate(data, config)
  secs <- proc.time()[["elapsed"]] - t0

  tv <- true_value(config)
  covered <- if (is.na(tv$truth)) {
    NA_integer_
  } else {
    as.integer(tv$truth >= est$ci_lower & tv$truth <= est$ci_upper)
  }

  data.frame(
    unit         = unit_row$unit,
    config_id    = unit_row$config_id,
    rep_id       = unit_row$rep_id,
    dgp          = config$dgp,
    n            = config$n,
    lambda       = config$lambda,
    method       = config$method,
    estimate     = est$estimate,
    std_error    = est$std_error,
    ci_lower     = est$ci_lower,
    ci_upper     = est$ci_upper,
    truth        = tv$truth,
    truth_source = tv$source,
    error        = est$estimate - tv$truth,  # ESTIMATION error (bias); NOT a failure flag
    covered      = covered,
    M_final      = est$M_final,
    converged    = as.integer(est$converged),
    secs         = secs,
    error_msg    = NA_character_,            # failure text; set by the runner on throw
    stringsAsFactors = FALSE
  )
}
