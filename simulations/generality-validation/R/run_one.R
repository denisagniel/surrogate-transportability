# =============================================================================
# run_one.R -- run a single work unit (one config x one replication)
# =============================================================================
# Pure w.r.t. its seed: same unit row -> same one-row data frame. Emits BOTH the
# raw canonical estimate and the jackknife bias-corrected estimate (Phase 0
# decision: compute both, always), plus per-DGP identity so the ensemble can be
# summarized by DGP kind / seed.
#
# Contract: input = one row of unit_table() (config cols + ids/seed + rho_true);
# output = ONE-ROW data.frame with an `estimate` column (profile_timing.R treats
# all-NA `estimate` as a failed unit). SHOULD include `error_msg` (character, NA
# on success): run_replication.R wraps run_one() in a tryCatch and fills it with
# the condition message when a replication throws, so a failure persists its
# ERROR TEXT rather than a silent all-NA row (Constitution Section 9).
# NOTE: the numeric `error`/`error_jk` columns are ESTIMATION error (estimate -
# truth), DISTINCT from `error_msg` (failure text). Do not conflate them.
#
# Assumes generate_data(), estimate(), true_value() sourced (dgp.R, estimators.R),
# and grid.R for column names.
# =============================================================================

run_one <- function(unit_row) {
  set.seed(unit_row$seed)
  config <- unit_row  # carries all grid columns + ids/seed/rho_true

  data  <- generate_data(config)
  est   <- estimate(data, config)
  truth <- true_value(config)

  covered    <- as.integer(truth >= est$ci_lower    & truth <= est$ci_upper)
  covered_jk <- as.integer(truth >= est$ci_lower_jk & truth <= est$ci_upper_jk)

  data.frame(
    unit       = unit_row$unit,
    config_id  = unit_row$config_id,
    rep_id     = unit_row$rep_id,
    dgp_kind   = config$dgp_kind,
    dgp        = config$dgp,
    dgp_seed   = config$dgp_seed,
    n          = config$n,
    lambda     = config$lambda,
    method     = config$method,
    truth      = truth,
    # raw canonical estimate
    estimate   = est$estimate,
    std_error  = est$std_error,
    ci_lower   = est$ci_lower,
    ci_upper   = est$ci_upper,
    error      = est$estimate - truth,
    covered    = covered,
    # jackknife bias-corrected estimate
    rho_jk     = est$rho_jk,
    jk_bias    = est$jk_bias,
    ci_lower_jk = est$ci_lower_jk,
    ci_upper_jk = est$ci_upper_jk,
    error_jk   = est$rho_jk - truth,
    covered_jk = covered_jk,
    # diagnostics
    M_final    = est$M_final,
    converged  = as.integer(est$converged),
    error_msg  = NA_character_,          # failure text; set by run_replication.R on throw
    stringsAsFactors = FALSE
  )
}
