# =============================================================================
# run_one_stage2.R -- one Stage 2 replication: generate continuous-X data, sample
# the discretize-to-cells geometry, estimate Theta (debiased), score coverage.
# =============================================================================
# Pure function of unit_row (seed + design + n + lambda + K). The TRUE Theta is
# computed from the DGP's true cell CATEs and the SAME sampled Sigma (conditional
# on geometry). Returns ONE row. Depends on dgp_smooth.R, dgp_theta.R,
# pseudo_outcome.R, bilinear_estimator.R (make_folds), theta_estimator.R, and
# library(surrogateTransportability) + library(grf) sourced/loaded by the caller.
# =============================================================================

run_one_stage2 <- function(unit_row) {
  set.seed(unit_row$seed)
  cfg <- list(d = 1L, s_S = unit_row$s_S, s_Y = unit_row$s_Y)
  K <- as.integer(unit_row$K)
  yd <- if (!is.null(unit_row$y_decorr)) unit_row$y_decorr else 0

  dat <- generate_stage1(unit_row$n, cfg, y_decorr = yd)

  # geometry: sample Sigma once for this replication (conditional-on-geometry).
  Sig <- sample_geometry(K, unit_row$lambda, M = 800, burn_in = 200, thin = 2)

  # true Theta from true cell CATEs + this Sigma.
  tS_true <- true_cell_cate(cfg, "S", K)
  tY_true <- true_cell_cate(cfg, "Y", K, y_decorr = yd)
  truth <- theta_true_from_cells(tS_true, tY_true, Sig)

  rr <- theta_hat_stage2(dat, Sig, K)

  data.frame(
    unit = unit_row$unit, config_id = unit_row$config_id, rep_id = unit_row$rep_id,
    design = unit_row$design, s_S = cfg$s_S, s_Y = cfg$s_Y, n = unit_row$n,
    lambda = unit_row$lambda, K = K,
    estimate = rr$theta, std_error = rr$se,
    ci_lower = rr$ci_lower, ci_upper = rr$ci_upper,
    truth = truth, error = rr$theta - truth,
    covered = as.integer(truth >= rr$ci_lower & truth <= rr$ci_upper),
    stringsAsFactors = FALSE
  )
}
