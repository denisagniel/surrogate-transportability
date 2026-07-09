# =============================================================================
# run_one_stage1.R -- one Stage 1 replication: generate, estimate, score.
# =============================================================================
# Pure function of unit_row (which carries seed + design columns). Returns ONE
# row (data.frame) with the debiased AND plug-in estimate/SE/coverage against the
# closed-form truth for the requested functional pair. Same-unit -> same output.
# Depends on dgp_smooth.R, pseudo_outcome.R, bilinear_estimator.R being sourced.
# =============================================================================

run_one_stage1 <- function(unit_row) {
  set.seed(unit_row$seed)
  cfg <- list(d = as.integer(unit_row$d), s_S = unit_row$s_S, s_Y = unit_row$s_Y)
  dat <- generate_stage1(unit_row$n, cfg)
  truth <- psi_truth_config(cfg)[[unit_row$pair]]

  rr <- psi_hat_dirac(dat, unit_row$pair, cfg$s_S, cfg$s_Y, cfg$d)

  # emit both estimators as two rows so the grid's `estimator` column selects.
  mk <- function(est, se, lo, hi, tag) {
    data.frame(
      unit = unit_row$unit, config_id = unit_row$config_id, rep_id = unit_row$rep_id,
      design = unit_row$design, d = cfg$d, s_S = cfg$s_S, s_Y = cfg$s_Y,
      regime = unit_row$regime, n = unit_row$n, pair = unit_row$pair,
      estimator = tag,
      estimate = est, std_error = se, ci_lower = lo, ci_upper = hi,
      truth = truth, error = est - truth,
      covered = as.integer(truth >= lo & truth <= hi),
      stringsAsFactors = FALSE
    )
  }
  rbind(
    mk(rr$psi_debiased, rr$se_debiased, rr$ci_lower_deb, rr$ci_upper_deb, "debiased"),
    mk(rr$psi_plugin,   rr$se_plugin,   rr$ci_lower_plug, rr$ci_upper_plug, "plugin")
  )
}
