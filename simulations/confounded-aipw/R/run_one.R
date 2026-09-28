# =============================================================================
# run_one.R -- run a single work unit (one config x one replication)
# =============================================================================
# run_one() is pure with respect to its seed: given the same unit row it always
# returns the same one-row data frame. It must not depend on any driver-specific
# state, so the same function serves the local driver and any future cluster
# submission.
#
# Contract (matching canonical-validation/R/run_one.R so this study can be handed
# to the O2 scaffold unchanged):
#   input : unit_row -- one row of unit_table()
#   output: a ONE-ROW data.frame. MUST include `estimate` (the scaffold's
#           profiler treats an all-NA `estimate` as a failed replication) and
#           SHOULD include `error_msg` (failure text, NA on success; set by the
#           caller's tryCatch, not here).
#   NOTE: the numeric `error` column is the ESTIMATION error (estimate - truth).
#         It is DISTINCT from `error_msg` (failure text). Do not conflate them.
# =============================================================================

run_one <- function(unit_row) {
  set.seed(unit_row$seed)

  data  <- generate_data(unit_row)
  est   <- estimate(data, unit_row)
  truth <- true_value(unit_row)

  covered <- as.integer(truth >= est$ci_lower & truth <= est$ci_upper)

  # Second error column, specific to this study: distance from what the
  # importance-weighting path actually converges to. For a randomized DGP
  # rho_iw_limit == rho_true and this equals `error`; under confounding the two
  # diverge, and an IW arm whose estimate sits near rho_iw_limit rather than near
  # rho_true is the study's central claim made numerical.
  error_vs_iw_limit <- est$estimate - as.numeric(unit_row$rho_iw_limit)

  data.frame(
    unit              = unit_row$unit,
    config_id         = unit_row$config_id,
    rep_id            = unit_row$rep_id,
    block             = unit_row$block,
    dgp_kind          = unit_row$dgp_kind,
    dgp               = unit_row$dgp,
    n                 = unit_row$n,
    lambda            = unit_row$lambda,
    method            = unit_row$method,
    estimate          = est$estimate,
    std_error         = est$std_error,
    ci_lower          = est$ci_lower,
    ci_upper          = est$ci_upper,
    truth             = truth,
    rho_iw_limit      = as.numeric(unit_row$rho_iw_limit),
    error             = est$estimate - truth,
    error_vs_iw_limit = error_vs_iw_limit,
    covered           = covered,
    M_final           = est$M_final,
    converged         = as.integer(est$converged),
    n_clipped         = est$n_clipped,
    error_msg         = NA_character_,
    stringsAsFactors  = FALSE
  )
}
